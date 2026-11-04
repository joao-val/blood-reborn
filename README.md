<div align="center">

# 🩸 Blood Reborn

**Free Bloodborne mods for the BB Port (PC)**

[![English](https://img.shields.io/badge/English-selected-8b0000?style=for-the-badge)](README.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-ler%20em%20portugu%C3%AAs-2f2f2f?style=for-the-badge)](README.pt-BR.md)

</div>

---

## The mods

| Mod | Version | What it does |
|---|---|---|
| **Hunter's Arsenal: Blood Pacts** | 1.0 | New special attacks for the trick weapons (R2+L2 in the transformed mode), inspired by Elden Ring skills and rebuilt for Bloodborne. Runes and gems with **pacts**: 14 pacts rolled on the gems you find. Includes 9 code patches. |
| **Merciless Night** | 1.31 | Tougher, more modern bosses and enemies: a second health bar and new phases on several bosses, shorter recovery between attacks, more aggressive AI, rebalanced health and damage. Includes 1 code patch (cloth physics fix). |
| **Fogside Lantern** | 1.6.1 *(testing)* | Died in a boss fight? You respawn right outside the boss fog, at the boss lantern. |
| **Blood Vial Safety Net** | 1.0.1 *(testing)* | After you die and respawn, your Blood Vials go back up to 11. It only adds what is missing, never during a fight. |

The mods work alone or together. Where two of them change the same game file, a small compatibility folder (**zCompat**) merges both.

## You need

- The **BB Port** installed and working.
- Your own **Bloodborne** dump (CUSA03173), game version **1.09**.
- A copy of your save folder somewhere safe, just in case (BB Port folder ➜ `user` ➜ `savedata`).

## Blood Reborn Mod Manager *(in development)*

A small mod manager, made only for the Blood Reborn mods. It does **not** launch the game: you keep playing through the BB Port as usual.

- **Install, remove and update** each mod, showing the installed version, the latest version and *what changed*.
- **Checks for updates on GitHub and on Nexus Mods**, with no login needed.
  - GitHub: one-click download.
  - Nexus Premium: one-click download with your API key.
  - Nexus free accounts: it opens the file page, you click *Manual download*, and it installs the zip as soon as it lands in your Downloads folder.
- **Fixes conflicts with any other mod** in your `mods` folder. It merges what can be merged into a folder at the end of the load order, and lists what cannot, so you choose which mod wins (Blood Reborn is the recommended choice).
- Never writes to your game files or to other people's mods.

Design: [docs/manager-design.md](docs/manager-design.md).

## How updates are published

[`catalog.json`](catalog.json) lists every mod with its current version, the notes of each version, the download (a GitHub release asset) and its Nexus Mods page. Publishing a new version means building the package, attaching it to a GitHub release and updating the catalog. The manager reads the catalog to know what is new.

## Credits and legal

- Made by **joao-val**.
- Not affiliated with FromSoftware, Sony Interactive Entertainment or the BB Port project.
- Bloodborne is a trademark of Sony Interactive Entertainment. You need your own legally obtained copy of the game.
