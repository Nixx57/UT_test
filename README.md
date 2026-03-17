# NixxPackage

UnrealScript package for Unreal Tournament (1999), built around a custom console (`NixxConsole`) and a custom ladder team (`NixxTeamInfo`).

The project was initially created to apply basic ballistic rules in Unreal Tournament and observe the in-game results. Over time, features were added and removed just for fun.

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

## Math

This section summarizes the math-oriented parts of the aiming logic implemented in `NixxConsole`.

### 1) Velocity Estimation

The code stores recent target positions in a ring buffer (`PreviousLocations[32]`) with timestamps.

For each valid consecutive sample pair:

$$
\vec{v}_i = \frac{\vec{p}_{i+1} - \vec{p}_i}{t_{i+1} - t_i}
$$

Then it computes a weighted average (newer samples have higher weight):

$$
\hat{\vec{v}} = \frac{\sum_i w_i\vec{v}_i}{\sum_i w_i}
$$

If there are fewer than 3 valid samples, velocity falls back to zero.

Algorithm type:
- Finite differences for derivatives.
- Weighted moving average for noise reduction.

How it is used:
- Output of `CalculateCustomVelocity()` feeds the intercept prediction in `BulletSpeedCorrection()`.

### 2) Acceleration Estimation

Acceleration is estimated from differences of successive velocity estimates:

$$
\vec{a}_i = \frac{\vec{v}_{i}^{(current)} - \vec{v}_{i}^{(previous)}}{\Delta t_{avg}}
$$

with:

$$
\Delta t_{avg} = \frac{\Delta t_{current} + \Delta t_{previous}}{2}
$$

The final acceleration uses weighted averaging, again favoring recent samples:

$$
\hat{\vec{a}} = \frac{\sum_i w_i\vec{a}_i}{\sum_i w_i}
$$

If fewer than 3 valid samples exist, acceleration falls back to zero.

Algorithm type:
- Second-order finite difference style estimate.
- Weighted smoother to reduce jitter.

How it is used:
- Output of `CalculateCustomAcceleration()` is combined with velocity to predict where the target will be at projectile arrival time.

### 3) Trajectory Prediction (Intercept)

For non-instant weapons, the code computes time-of-flight (ToF) and predicts future target position.

Initial estimate:

$$
ToF = \frac{\|\vec{p}_{target} - \vec{p}_{muzzle}\|}{v_{projectile}}
$$

Predicted displacement:

$$
\Delta\vec{p} = \hat{\vec{v}}\,ToF + \frac{1}{2}\hat{\vec{a}}\,ToF^2
$$

The code refines ToF iteratively (3 passes):
1. Predict future aim spot.
2. Recompute distance to that spot.
3. Update ToF.

Algorithm type:
- Kinematic extrapolation with constant acceleration.
- Fixed small-count iterative refinement.

How it is used:
- Implemented in `BulletSpeedCorrection()` and added to target aim point before final rotation.

### 4) Projectile Physics Handling (Gravity)

If projectile physics is `PHYS_Falling`, the code applies a vertical compensation term using zone gravity (`ZoneGravity.Z`) and an additional empirical boost:

$$
\Delta z_{gravity} = 200\cdot ToF + \frac{1}{2}g\,ToF^2
$$

Then:

$$
\Delta p_z \leftarrow \Delta p_z - \Delta z_{gravity}
$$

Notes:
- `g` is read from the current zone gravity.
- The `200 * ToF` term is a practical tuning term (empirical), not a pure physics constant.

Algorithm type:
- Ballistic compensation with engine-specific tuning.

How it is used:
- Keeps predicted aim aligned with gravity-affected projectile paths.

### 5) Robustness and Line-of-Sight Constraints

After prediction, the code checks if the corrected point is traceable (`FastTrace`).
If blocked, correction is repeatedly halved until valid (or near zero):

$$
\Delta\vec{p} \leftarrow \frac{1}{2}\Delta\vec{p}
$$

Algorithm type:
- Geometric feasibility check + iterative damping.

How it is used:
- Prevents aggressive over-prediction through walls and keeps aim corrections stable in real maps.

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
