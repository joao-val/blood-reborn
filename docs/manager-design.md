# Blood Reborn Mod Manager — Design

Status: approved by the author on 2026-11-04. Implementation follows the build order at the end.

## 1. Goal

Replace the current one-shot installer with a small **mod manager** for the Blood Reborn mods that:

1. installs, removes and **updates** each mod from inside the manager, showing the installed version, the latest version and what changed;
2. checks for updates on **GitHub and Nexus Mods**;
3. finds and resolves **conflicts between Blood Reborn mods and any other mod** in the BB Port `mods` folder.

## 2. Decisions taken by the author

| Topic | Decision |
|---|---|
| Launching the game | The manager does **not** launch the game. Players keep opening Bloodborne through the BB Port. |
| Window | Keep the current window (PowerShell + WPF, BB Port look, PT/EN/ES/ZH). Replace the BB Port symbol with the Hunter's Mark. |
| Update sources | GitHub and Nexus Mods. GitHub hosts a catalog file and the release packages. |
| Downloads | GitHub: direct. Nexus Premium: direct with the player's API key. Nexus free: open the file page, the player clicks *Manual download*, the manager watches the Downloads folder and installs the zip. Fallback: a zip dropped next to the manager. |
| Conflicts | Merge what can be merged into a generated folder at the end of the load order. For what cannot be merged, the player chooses who wins; **Blood Reborn wins** is pre-selected as the recommendation. The choice is remembered. |
| zCompat warnings | Kept. |
| Boss Arena | Out of scope. |

## 3. Components

| Unit | What it does | Depends on |
|---|---|---|
| `BloodReborn.ps1` (exists, extended) | Engine: read packages and the catalog, install/remove/update, record installed versions, watch Downloads, diagnose. Also runs headless (`-Acao`) for tests. | PowerShell 5.1, .NET zip |
| `BloodReborn_janela.ps1` (exists, extended) | Window: pages *Mods* (install, remove, update, what changed), *Error fixing* (conflicts with choices), *How to install*, *Settings* (optional Nexus API key). | `BloodReborn.ps1` |
| `merge/` (new, Python) | Merge engine: the Blood Reborn asset loader (three-way conflict check against the game files) run offline. Reads every enabled mod, writes the merged files to the generated folder, returns a JSON conflict report. | The BB Port's own Python (`Bloodborne.exe --script`), Python standard library only |
| `catalog.json` (GitHub, this repository) | Current version, notes and download of each mod. | — |
| `tools/publish.py` (new, author side) | Builds the packages, attaches them to a GitHub release, updates `catalog.json`. | `gh`, the package generator |

When the BB Port's Python is not available (an unknown port build), the manager falls back to **detection only** (file overlaps between mods) and to the prebuilt zCompat folders shipped in the packages.

## 4. Package format (one zip per mod)

- `<top>/mods/<folder>/dvdroot_ps4/...`: the mod as **whole files**, ready to use with a plain BB Port (manual install keeps working).
- `<top>/patches/*.xml`: code patches, if any.
- `<top>/recipe/`: the mod as a **recipe** — the declarative patch manifest (`bbport-patches.json`) and the minimal templates. The merge engine uses it to merge the mod with any other mod.
- `<top>/blood_reborn.json`: key, name, folder, version, catalog key, Nexus mod id, notes of this version (PT/EN/ES/ZH; missing languages fall back to English).
- `Compatibilidade - Compatibility/`: the prebuilt zCompat folders (used only in detection-only mode).

## 5. Catalog (`catalog.json`)

```json
{
  "schema": 1,
  "updated": "YYYY-MM-DD",
  "github": {"repository": "joao-val/blood-reborn"},
  "nexus": {"game_domain": "bloodborne", "game_id": 2708},
  "mods": [{
    "key": "merciless_night", "name": "Merciless Night", "folder": "Blood Reborn - Merciless Night",
    "version": "1.31", "status": "released | testing",
    "package": "<zip name>", "sha256": "<zip SHA-256>",
    "download": "<GitHub release asset URL, or null>",
    "nexus_mod_id": null, "nexus_file_id": null,
    "changes": {"1.31": {"en": "...", "pt": "..."}}
  }]
}
```

`download`, `nexus_mod_id` and `nexus_file_id` are `null` until the mod is published there; the manager then skips that source.

## 6. Update flow

1. **When:** on start (at most once a day, cached) and on the *Check for updates* button.
2. **Read** `https://raw.githubusercontent.com/joao-val/blood-reborn/main/catalog.json` (no login). For mods with a Nexus id, also query the public Nexus GraphQL API (`https://api.nexusmods.com/v2/graphql`, `legacyModsByDomain` and `modFiles`; no key; headers `Application-Name` and `Application-Version`). Verified on 2026-11-04: it returns name, version, update date and the file list with versions.
3. **Installed version:** the manager writes `blood_reborn_installed.json` (key, version, SHA-256 of each file, date) inside the mod folder when it installs. A mod installed by hand is recognised by the SHA-256 of its files against the known versions; otherwise it shows *unknown version — reinstall*.
4. **Show:** "Installed 1.31 · Available 1.32", *What changed* (notes of every version in between), **Update**.
5. **Download**, first source that works:
   1. GitHub release asset (direct);
   2. Nexus Premium: `download_link` of the v1 API with the player's API key (stored only on the player's PC);
   3. Nexus free: open `https://www.nexusmods.com/bloodborne/mods/<id>?tab=files&file_id=<file>`, watch the Downloads folder for the expected zip name, up to 30 minutes;
   4. a zip dropped next to the manager.

   Every downloaded zip is checked against `sha256` in the catalog before use.
6. **Apply:** wait until the game is closed; move the current mod folder to a backup (one previous version kept, for *Roll back*); install the new one; update the code patches; rerun the merge.

## 7. Conflict flow (page *Error fixing*)

1. The merge runs after every change made through the manager. On start, the manager compares a fingerprint of the `mods` folder (names, sizes, dates, `mods.json`) with the last merge; if it changed (a mod added by hand), it warns and offers to merge again.
2. The engine composes, in the BB Port load order, every enabled mod: whole files of other mods as they are, Blood Reborn mods by recipe, with the three-way check against the player's own game files. The result goes to a generated folder (`Blood Reborn - zMerge (generated)`), placed **last** in the load order.
3. **Conflicts** reported by the engine:
   - the same unit (param row or field, file inside an archive, TAE animation, FMG text, EMEVD event) changed by two mods in different ways;
   - a file that cannot be merged (loose files such as `.hks`, sound banks, unknown formats) changed by two mods.
4. Each conflict shows both mods and what clashes, with **Blood Reborn wins (recommended)** pre-selected and *The other mod wins* as the alternative. Choices are stored in `%APPDATA%\BloodReborn\choices.json` and applied on every merge.
5. The existing diagnostics stay: patch without its mod, zCompat missing, extra or out of order, disabled mod with its patches on, leftovers of manual installs.

## 8. What the manager writes on the player's PC

| Where | What |
|---|---|
| `<BB Port>\mods\Blood Reborn - *\` | the Blood Reborn mods and their `blood_reborn_installed.json` |
| `<BB Port>\mods\Blood Reborn - zMerge (generated)\` | merged files |
| `<BB Port>\mods.json` | order and on/off of the Blood Reborn folders only |
| `<BB Port>\patches\` + `patches.json` | the Blood Reborn code patches |
| `%APPDATA%\BloodReborn\` | settings, Nexus API key (optional), conflict choices, update cache, backups of the previous version |

It never writes to the game files nor to folders of other mods.

## 9. Error handling

- No internet, GitHub or Nexus down: work with local packages; show a short notice, never block.
- Download with a wrong SHA-256: discard it and say so.
- Game running: wait (button disabled with the reason).
- Merge engine error or no Python: keep the previous generated folder, show the error, offer detection-only mode.
- Nexus rate limit: one catalog check per day, cached.

## 10. Testing

- Headless scenarios on a fake BB Port folder (as the current installer tests): install; update 1.0 → 1.1 from a local fake catalog; roll back; mod installed by hand (known and unknown version); conflict with a fake third-party mod (same param row equal and different, a loose file); no Python; no internet.
- Merge engine regression: same output as the Blood Reborn development loader, byte for byte, on the author's mod set.
- Window captures in the four languages.

## 11. Build order

1. Repository and catalog (this commit).
2. Updates — done (plan: [docs/plans/2026-11-04-phase-2-updates.md](plans/2026-11-04-phase-2-updates.md)).
3. Merge engine and conflicts page.
4. Hunter's Mark symbol (read at runtime from the player's game files, never shipped) and window review.
5. `tools/publish.py` and the first GitHub release.

## 12. Out of scope

- Launching the game.
- Boss Arena support.
- Registering the manager as the `nxm://` handler (it would take the *Mod Manager Download* button away from Vortex or Mod Organizer).
