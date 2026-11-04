<div align="center">

# 🩸 Blood Reborn

**Free Bloodborne mods for the BB Port (PC)** 🌙

[![English](https://img.shields.io/badge/English-8b0000?style=for-the-badge)](README.md)
[![Português](https://img.shields.io/badge/Portugu%C3%AAs-2f2f2f?style=for-the-badge)](README.pt-BR.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-2f2f2f?style=for-the-badge)](README.es.md)
[![中文](https://img.shields.io/badge/%E4%B8%AD%E6%96%87-2f2f2f?style=for-the-badge)](README.zh-CN.md)

</div>

---

## ⚔️ The mods

### 💎 Hunter's Arsenal: Blood Pacts — v1.0

New **special attacks** for the trick weapons (R2+L2 in the transformed mode), inspired by Elden Ring skills and rebuilt for Bloodborne. But the heart of this mod is the **Blood Pacts**.

🩸 **Every pact is a deal: a power, and a price.**

- 💎 The **gems** you find can come with one of **14 pacts**. The stronger the gem, the stronger the pact (Pact 1, 2 and 3), and the price grows with it.
- 🏆 The deeper the Chalice, the more pacts: 60% of the gems in the world and in shallow Chalices, 80% in medium depths, 90% in the deepest ones. Farming gems is worth it again.
- ✨ **Caryll Runes** carry pacts too.
- 📜 Each pact shows up as its own line on the gem and weapon screens, in all 21 languages of the game.

A taste of what you can find:

| 🩸 The power | 💀 The price |
|---|---|
| Below 30% HP, stamina comes back faster | You take more damage |
| Blood Vials heal more | Lower max stamina |
| A visceral attack gives back a bullet and a free special | You take more damage |
| Hitting with a special drinks back some HP | Your health slowly drains |
| Hitting with a special gives back a Quicksilver Bullet | Fewer max bullets |
| Each hit in a row raises your attack | Each hit raises the damage you take |
| A perfect dodge raises your attack for a moment | Dodging costs more stamina |
| With 40+ Insight, your specials hit harder | Lower frenzy resistance |
| More damage against beasts | Less damage against everything else |
| Your rally also restores stamina | You take more damage |
| More Quicksilver Bullets | Specials cost one more bullet |

🔧 Includes 9 code patches (installed for you).

### 🌙 Merciless Night — v1.31

The night got crueler. 🌑

Bosses, hunters and beasts were reworked for a **more dynamic, modern and challenging** Bloodborne. We won't spoil what changed: you will find out in the fight. 😈

💬 **Feedback is very welcome.** Tell us what felt fair, what felt cruel, and what felt *too* cruel.

🔧 Includes 1 code patch (installed for you).

### 🏮 Fogside Lantern — v1.6.1 *(testing)*

Died in a boss fight? You respawn right outside the boss fog. No more long walks back. 🚶‍♂️

### 🧪 Blood Vial Safety Net — v1.0.1 *(testing)*

After you die and respawn, your Blood Vials go back up to 11. It only adds what is missing, and never during a fight. 💉

---

## 🧩 Better together

Every mod works alone or with the others. Where two of them change the same game file, a small compatibility folder (**zCompat**) merges both.

## ✅ You need

- 🎮 The **BB Port** installed and working.
- 💿 Your own **Bloodborne** dump (CUSA03173), game version **1.09**.
- 💾 A copy of your save folder somewhere safe, just in case (BB Port folder ➜ `user` ➜ `savedata`).

## 🧰 Blood Reborn Mod Manager *(in development)*

A small mod manager, made only for the Blood Reborn mods. It does **not** launch the game: you keep playing through the BB Port as usual.

- 📦 **Install, remove and update** each mod, with the installed version, the latest version and *what changed*.
- 🔄 **Checks for updates on GitHub and on Nexus Mods**, no login needed.
  - 🐙 GitHub: one-click download.
  - ⭐ Nexus Premium: one-click download with your API key.
  - 🆓 Nexus free account: it opens the file page, you click *Manual download*, and it installs the zip as soon as it lands in your Downloads folder.
- 🛠️ **Fixes conflicts with any other mod** in your `mods` folder: it merges what can be merged into a folder at the end of the load order, and lists what cannot, so you choose which mod wins (Blood Reborn is the recommended choice).
- 🛡️ Never writes to your game files or to other people's mods.

📐 Design: [docs/manager-design.md](docs/manager-design.md)

## 🔄 How updates are published

[`catalog.json`](catalog.json) lists every mod with its current version, the notes of each version, the download (a GitHub release asset) and its Nexus Mods page. A new version means: build the package, attach it to a GitHub release, update the catalog. The manager reads the catalog to know what is new.

## 💬 Feedback

Found a bug, a crash, or a boss that is simply unfair? Open an [issue](https://github.com/joao-val/blood-reborn/issues). Every report helps the night get better. 🩸

## 📜 Credits and legal

- Made by **joao-val**.
- Not affiliated with FromSoftware, Sony Interactive Entertainment or the BB Port project.
- Bloodborne is a trademark of Sony Interactive Entertainment. You need your own legally obtained copy of the game.
