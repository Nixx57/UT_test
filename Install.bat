@echo off
setlocal EnableDelayedExpansion

set "SYSDIR=%~dp0..\System"
set "UT_INI=%SYSDIR%\UnrealTournament.ini"
set "USER_INI=%SYSDIR%\User.ini"

echo ============================================
echo   NixxPackage - Installation
echo ============================================
echo.

REM --- Verify files exist ---
if not exist "%UT_INI%" (
    echo ERROR: UnrealTournament.ini not found in %SYSDIR%
    goto :error
)
if not exist "%USER_INI%" (
    echo ERROR: User.ini not found in %SYSDIR%
    goto :error
)

REM ============================================
REM  Step 1: UnrealTournament.ini - [Engine.Engine]
REM  Comment Console=UTMenu.UTConsole and add Console=NixxPackage.NixxConsole
REM ============================================
echo [1/5] Section [Engine.Engine] - Console...

findstr /C:"Console=NixxPackage.NixxConsole" "%UT_INI%" >nul 2>&1
if !errorlevel! equ 0 (
    echo       Already done. Skipping.
) else (
    powershell -NoProfile -Command ^
        "$file = Get-Content '%UT_INI%' -Encoding Default;" ^
        "$out = @();" ^
        "foreach ($line in $file) {" ^
        "  if ($line.Trim() -eq 'Console=UTMenu.UTConsole') {" ^
        "    $out += ';Console=UTMenu.UTConsole';" ^
        "    $out += 'Console=NixxPackage.NixxConsole';" ^
        "  } elseif ($line.Trim() -eq ';Console=UTMenu.UTConsole') {" ^
        "    $out += $line;" ^
        "  } else {" ^
        "    $out += $line;" ^
        "  }" ^
        "}" ^
        "$out | Set-Content '%UT_INI%' -Encoding Default;"
    if !errorlevel! neq 0 goto :error
    echo       OK.
)

REM ============================================
REM  Step 2: UnrealTournament.ini - [Engine.GameEngine]
REM  Add ServerPackages=NixxPackage
REM ============================================
echo [2/5] Section [Engine.GameEngine] - ServerPackages...

findstr /C:"ServerPackages=NixxPackage" "%UT_INI%" >nul 2>&1
if !errorlevel! equ 0 (
    echo       Already done. Skipping.
) else (
    powershell -NoProfile -Command ^
        "$file = Get-Content '%UT_INI%' -Encoding Default;" ^
        "$out = @();" ^
        "$inSection = $false;" ^
        "$added = $false;" ^
        "foreach ($line in $file) {" ^
        "  if ($line.Trim() -match '^\[Engine\.GameEngine\]$') {" ^
        "    $inSection = $true;" ^
        "    $out += $line;" ^
        "    continue;" ^
        "  }" ^
        "  if ($inSection -and $line.Trim() -match '^\[' -and -not $added) {" ^
        "    $out += 'ServerPackages=NixxPackage';" ^
        "    $added = $true;" ^
        "    $inSection = $false;" ^
        "  }" ^
        "  $out += $line;" ^
        "}" ^
        "if ($inSection -and -not $added) { $out += 'ServerPackages=NixxPackage'; }" ^
        "$out | Set-Content '%UT_INI%' -Encoding Default;"
    if !errorlevel! neq 0 goto :error
    echo       OK.
)

REM ============================================
REM  Step 3: UnrealTournament.ini - [Editor.EditorEngine]
REM  Add EditPackages=NixxPackage
REM ============================================
echo [3/5] Section [Editor.EditorEngine] - EditPackages...

findstr /C:"EditPackages=NixxPackage" "%UT_INI%" >nul 2>&1
if !errorlevel! equ 0 (
    echo       Already done. Skipping.
) else (
    powershell -NoProfile -Command ^
        "$file = Get-Content '%UT_INI%' -Encoding Default;" ^
        "$out = @();" ^
        "$inSection = $false;" ^
        "$added = $false;" ^
        "foreach ($line in $file) {" ^
        "  if ($line.Trim() -match '^\[Editor\.EditorEngine\]$') {" ^
        "    $inSection = $true;" ^
        "    $out += $line;" ^
        "    continue;" ^
        "  }" ^
        "  if ($inSection -and $line.Trim() -match '^\[' -and -not $added) {" ^
        "    $out += 'EditPackages=NixxPackage';" ^
        "    $added = $true;" ^
        "    $inSection = $false;" ^
        "  }" ^
        "  $out += $line;" ^
        "}" ^
        "if ($inSection -and -not $added) { $out += 'EditPackages=NixxPackage'; }" ^
        "$out | Set-Content '%UT_INI%' -Encoding Default;"
    if !errorlevel! neq 0 goto :error
    echo       OK.
)

REM ============================================
REM  Step 4: User.ini - [Engine.Input]
REM  Set MouseButton4, PageUp, PageDown
REM ============================================
echo [4/5] Section [Engine.Input] - Keybinds...

powershell -NoProfile -Command ^
    "$file = Get-Content '%USER_INI%' -Encoding Default;" ^
    "$changed = $false;" ^
    "$out = @();" ^
    "$inSection = $false;" ^
    "foreach ($line in $file) {" ^
    "  if ($line.Trim() -match '^\[Engine\.Input\]$') { $inSection = $true; $out += $line; continue; }" ^
    "  if ($line.Trim() -match '^\[' -and $line.Trim() -notmatch '^\[Engine\.Input\]$') { $inSection = $false; }" ^
    "  if ($inSection) {" ^
    "    if ($line -match '^MouseButton4=' -and $line.Trim() -ne 'MouseButton4=doAutoaim') {" ^
    "      $out += 'MouseButton4=doAutoaim'; $changed = $true; continue;" ^
    "    }" ^
    "    if ($line -match '^PageUp=' -and $line.Trim() -ne 'PageUp=IncreaseSpeed') {" ^
    "      $out += 'PageUp=IncreaseSpeed'; $changed = $true; continue;" ^
    "    }" ^
    "    if ($line -match '^PageDown=' -and $line.Trim() -ne 'PageDown=ReduceSpeed') {" ^
    "      $out += 'PageDown=ReduceSpeed'; $changed = $true; continue;" ^
    "    }" ^
    "  }" ^
    "  $out += $line;" ^
    "}" ^
    "if ($changed) { $out | Set-Content '%USER_INI%' -Encoding Default; Write-Host 'CHANGED'; } else { Write-Host 'ALREADY_OK'; }"

if !errorlevel! neq 0 goto :error
echo       OK.

REM ============================================
REM  Step 5: Compile
REM ============================================
echo [5/5] Compiling...
echo.

call "%~dp0Compile.bat"
goto :end

:error
echo.
echo ERROR: Installation failed.
pause
exit /b 1

:end
echo.
echo Installation complete.
pause
exit /b 0
