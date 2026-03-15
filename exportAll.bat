@echo off
setlocal

set UT_DIR=C:\UnrealTournament
set OUTPUT_DIR=C:\UnrealTournament\NixxPackage\UncodeX

echo Starting source code extraction...

if not exist "%OUTPUT_DIR%" (
    echo Creating output directory: "%OUTPUT_DIR%"
    mkdir "%OUTPUT_DIR%"
)

for %%F in ("%UT_DIR%\System\*.u") do (
    echo Extracting source from: %%F
	"%UT_DIR%\System\ucc" batchexport %%F class uc "%OUTPUT_DIR%"
)

echo Source code extraction complete.
echo Files have been saved in "%OUTPUT_DIR%"

pause
endlocal