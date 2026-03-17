# NixxPackage

UnrealScript package for Unreal Tournament (1999), built around a custom console (`NixxConsole`) and a custom ladder team (`NixxTeamInfo`).

The project includes aim-assist features and utility commands (overlay, ladder randomization, bot tools, monster spawning).

## Warning

- Use only in private/offline contexts or on servers where it is explicitly allowed.
- This package may be detected/blocked by anti-cheat protections.

## Project Contents

- `Classes/NixxConsole.uc`: main logic (auto-aim, overlay, console commands, ladder tools).
- `Classes/NixxTeamInfo.uc`: custom ladder team "The Corrupt".
- `Install.bat`: automated ini setup + compilation.
- `Compile.bat`: compiles the package and pauses at the end.
- `CompileNoPause.bat`: same compilation without pause.
- `exportAll.bat`: exports classes from `.u` files into `UncodeX`.

## Requirements

- Unreal Tournament 99 installed.
- This repository placed in the game root folder as `NixxPackage`.
  - Expected example:
    - `C:\UnrealTournament\NixxPackage`
    - `C:\UnrealTournament\System\UnrealTournament.ini`

## Quick Installation (Recommended)

1. Open a terminal/cmd in the `NixxPackage` folder.
2. Run `Install.bat`.

This script automatically updates:
- `UnrealTournament.ini`:
  - section `[Engine.Engine]`: comments `Console=UTMenu.UTConsole` and adds `Console=NixxPackage.NixxConsole`.
  - section `[Engine.GameEngine]`: adds `ServerPackages=NixxPackage`.
  - section `[Editor.EditorEngine]`: adds `EditPackages=NixxPackage`.
- `User.ini` (section `[Engine.Input]`):
  - `MouseButton4=doAutoaim`
  - `PageUp=IncreaseSpeed`
  - `PageDown=ReduceSpeed`
- Runs compilation through `Compile.bat`.

## Manual Installation

If you do not want to use `Install.bat`, add these manually:

- In `System/UnrealTournament.ini`:
  - `[Engine.Engine]` -> `Console=NixxPackage.NixxConsole`
  - `[Engine.GameEngine]` -> `ServerPackages=NixxPackage`
  - `[Editor.EditorEngine]` -> `EditPackages=NixxPackage`
- Then compile with `Compile.bat` (or `CompileNoPause.bat`).

## Compilation

Compilation scripts delete `System/NixxPackage.u` and then run:

`UCC.exe Make`

## Main Features

- Smooth aim rotation (configurable).
- Projectile prediction (target velocity + acceleration, gravity compensation for falling projectiles).
- Supports player targets and monster targets (`ScriptedPawn`).
- Attempts Shock/Tazer combo on projectile near a valid target.
- In-game overlay for current settings.
- Ladder tools: custom team and ladder randomization (DM/CTF/DOM/AS/Challenge).
- Team bot tools (skills/aggressiveness) and team GodMode.
- Periodic monster spawning (toggle).

## Console Commands

Commands exposed by `NixxConsole`:

- `doAutoAim`: toggles auto-aim.
- `SetRotationSpeed <int>`: sets rotation speed.
- `IncreaseSpeed`: increases rotation speed (+100).
- `ReduceSpeed`: decreases rotation speed (-100).
- `UseSplash`: toggles splash logic.
- `UseRotateSlow`: toggles slow rotation.
- `AimPlayers`: toggles player targeting.
- `UseDebug`: toggles debug display.
- `SuperBotTeam`: boosts allied bots in team game.
- `GetSkills`: prints bot skills in-game.
- `GodModeTeam <0|1>`: disables/enables GodMode for team.
- `RandomizeLadders`: randomizes ladder map sets.
- `SpawnMonsters`: toggles periodic monster spawning.
- `ShowOverlay`: shows/hides overlay.

## Default Values

- `bAutoAim=True`
- `MySetSlowSpeed=2000`
- `bUseSplash=True`
- `bAimPlayers=True`
- `bShowOverlay=True`
- `bSpawnMonsters=False`

## Notes

- `UncodeX/` contains exported classes, useful for reference/code reading.
- The package is built for the UT99 ecosystem (UnrealScript + UCC).
