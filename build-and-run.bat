@echo off
setlocal
pushd "%~dp0" || exit /b 1

for /f "usebackq delims=" %%V in (".godot-version") do set "godot_version=%%V"
if not exist ".tools\godot\Godot_v%godot_version%-stable_win64_console.exe" goto setup
if not exist ".tools\templates\windows_release_x86_64.exe" goto setup
goto build

:setup
where py >nul 2>&1
if not errorlevel 1 (
    py -3 tools\setup-godot.py
) else (
    where python >nul 2>&1
    if errorlevel 1 (
        echo Python 3 is required to install the pinned Godot tools.
        goto failed
    )
    python tools\setup-godot.py
)
if errorlevel 1 goto failed

:build
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tools\dev.ps1" ExportWindows
if errorlevel 1 goto failed

"build\windows\Amelia.exe" %*
if errorlevel 1 goto failed

popd
exit /b 0

:failed
set "result=%errorlevel%"
echo Build or run failed with exit code %result%.
popd
exit /b %result%
