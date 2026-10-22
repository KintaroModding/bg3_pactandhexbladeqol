# Pact and Hexblade QoL

Pact of the Blade and Hexblade bind all your equipped weapons; a weapon loses its bind when you unequip it.

A mod for Baldur's Gate 3 (Patch 8), made with game version 4.1.1.7398727. It needs
[Norbyte's Script Extender](https://github.com/Norbyte/bg3se). This README is for developers. What the mod does, how
to install it and its compatibility are in [openmods.md](openmods.md), the mod page on
[openmods](https://openmods.nexus).

For [DnD 5.5e All-in-One BEYOND](https://mod.io/g/baldursgate3/m/bg3dnd), use
[bg3_pactandhexbladeqol_dnd55ebynd](https://github.com/KintaroModding/bg3_pactandhexbladeqol_dnd55ebynd): that mod
turns `Shout_PactOfTheBlade_Bind` into a container with four variants, and `CastedSpell` names the variant, so this
mod's listener never matches.

## How it works

- `Server/Binding.lua` (Osiris listeners on the server):
  - `CastedSpell` of `Shout_PactOfTheBlade_Bind` or `Shout_Hexblade_Bind`: every weapon in the slots `Melee Main
    Weapon`, `Melee Offhand Weapon`, `Ranged Main Weapon` and `Ranged Offhand Weapon` gets `PACT_BLADE` or
    `HEXBLADE_BIND` (`ApplyStatus(item, status, -1)`, only when it does not have it; the game's own spell binds the
    main hand with `ApplyEquipmentStatus(MainHand, ...)`).
  - `Unequipped`: the item loses both bind statuses. When the item is the summoned pact weapon (tag
    `PACT_OF_THE_BLADE`, `be460271-537a-4443-a9b5-6c6c6a005ab3`), the other equipped weapons lose theirs.
  - `Equipped`: when the character has a summoned pact weapon and it is equipped, the other equipped weapons get
    `PACT_BLADE`, or `HEXBLADE_BIND` with the passive `HexWarrior`; when it is not equipped, the equipped weapons lose
    their binds.
- `Shared/Spells.lua` changes five spells at run time, only these fields: `Shout_PactOfTheBlade` and
  `Shout_PactOfTheBlade_Hex` `Cooldown` `None`; `Shout_PactOfTheBlade_Bind` and `Shout_Hexblade_Bind` free
  (`UseCosts` empty), without `Requirements` (in combat too), a new `Description`, no `ExtraDescription`, and the
  warning `TooltipPermanentWarnings` (`TooltipExtras/TooltipExtraTexts.lsx`); `Shout_WeaponBond` free, without
  `Requirements`. The client applies them on `StatsLoaded`, the server again on `SessionLoaded`; only fields that
  differ are written, and only changed entries are synced. The logs list each entry as `changed`, `as wanted` or
  `missing`.
- The texts are in `Localization/English/bg3_pactandhexbladeqol.loca.xml` (`build.ps1` makes the `.loca`).

## Build

Requirements: Windows PowerShell and [LSLib](https://github.com/Norbyte/lslib/releases) (`Divine.exe`).
`build.ps1` looks for `_tools\lslib\Packed\Tools\Divine.exe` in the parent folders of the project; set `BG3_TOOLS` to
a folder that holds `lslib\` to use another place.

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1             # dist\bg3_pactandhexbladeqol.pak
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Deploy     # build, then copy the .pak to the Mods folder
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Wait      # copy the .pak when the game is closed
```

`deploy.ps1` copies the .pak to the `Mods` folder below `BG3_DATA_DIR` (the BG3 user-data folder), else to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`; `-ModsDir` overrides both. The running game locks the .pak, so
the script stops (exit code 2) or, with `-Wait`, waits until the game is closed.

## Project layout

```
src/                                     Mod files (packed into the .pak)
  Mods/bg3_pactandhexbladeqol/meta.lsx           Mod metadata (UUID 4d718cb3-aef1-4a2d-9517-a8a60cafad34)
  Mods/bg3_pactandhexbladeqol/ScriptExtender/
    Config.json
    Lua/BootstrapServer.lua              Server entry point
    Lua/BootstrapClient.lua              Client entry point
    Lua/Shared/Common.lua                Shared helpers (mod version)
    Lua/Shared/FileWriter.lua            Throttled file output in the Script Extender folder
    Lua/Server/ServerLog.lua             server.log
    Lua/Client/ClientLog.lua             client.log
    Lua/Shared/Spells.lua                The spell changes (both states)
    Lua/Server/Binding.lua               Bind on cast, unbind on unequip, the summoned pact weapon
  Localization/English/bg3_pactandhexbladeqol.loca.xml   Texts
  Public/bg3_pactandhexbladeqol/TooltipExtras/TooltipExtraTexts.lsx   The unbind warning of the bind spells
docs/                                    Cover and screenshots for openmods.md
tests/                                   Offline tests (Lua 5.4 through lupa)
scripts/bump_version.py                  Raises the last version digit in meta.lsx
scripts/show_log.py                      Prints the mod's log files
build.ps1                                Builds dist/bg3_pactandhexbladeqol.pak from src/ (.loca.xml -> .loca, .lsf.lsx -> .lsf)
deploy.ps1                               Copies the .pak to the Mods folder
openmods.json, openmods.md               Data and mod page for openmods.nexus
```

Versioning: every change raises the last version digit (1.0.0.0 -> 1.0.0.1):

```powershell
python scripts\bump_version.py           # both Version64 values in meta.lsx
python scripts\bump_version.py --show
```

Logs: the mod writes `server.log` and `client.log` to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\bg3_pactandhexbladeqol\`. Each load writes a line like
`Pact and Hexblade QoL 1.0.0.1 loaded.`, so the logs show which version runs. `python scripts\show_log.py` prints the newest
lines (from `BG3_DATA_DIR`, if set).

Tests:

```powershell
python -m pip install lupa
python tests\run_tests.py
```

The tests run every mod script against mocks of the Script Extender API (`tests/harness.lua`). The IMGUI, audio and
resource mocks are checked against the Script Extender IDE helpers (`tests/gen_extui_api.py` refreshes
`tests/extui_api.json`), so a property or method that does not exist in the real API fails the tests.

## License

MIT, see [LICENSE](LICENSE).
