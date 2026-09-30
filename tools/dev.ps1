param(
    [ValidateSet('Editor', 'Run', 'Test', 'ExportWeb', 'ExportWindows', 'CheckLocalisation')]
    [string]$Task = 'Editor',
    [string]$Python = 'python',
    [string[]]$Suites = @()
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$version = (Get-Content (Join-Path $root '.godot-version')).Trim()
$godot = Join-Path $root ".tools/godot/Godot_v$version-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $godot)) {
    throw 'Run python tools/setup-godot.py first.'
}
function Invoke-GodotTest([string[]]$Arguments, [string]$Label) {
    Write-Output "Running Godot checks: $Label"
    $previousErrorAction = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 wraps native stderr in ErrorRecord objects.
        # Capture them as text so our exit/assertion/leak checks decide failure.
        $ErrorActionPreference = 'Continue'
        $output = @(& $godot @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    $logDirectory = Join-Path $root 'build/test-logs'
    New-Item -ItemType Directory -Force $logDirectory | Out-Null
    $logPath = Join-Path $logDirectory (($Label -replace '[^a-zA-Z0-9_-]', '-') + '.log')
    $output | Set-Content -LiteralPath $logPath
    $output | Write-Output
    $text = $output -join "`n"
    if ($exitCode -ne 0 -or $text -match 'SCRIPT ERROR|Assertion failed|ObjectDB instances.*leaked|resources still in use at exit|RID allocations.*leaked' -or $text -notmatch 'PASS|"passed":true') {
        throw "Godot checks failed (including shutdown cleanup): $Label. Log: $logPath"
    }
}
Push-Location $root
$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
try {
    New-Item -ItemType Directory -Force build | Out-Null
    if (-not (Test-Path -LiteralPath build/.gdignore)) {
        New-Item -ItemType File -Path build/.gdignore | Out-Null
    }
    # Only automated runs use an isolated, writable Windows profile. Interactive
    # Editor/Run keep the user's normal preferences and voyage saves.
    if ($Task -in @('Test', 'ExportWeb', 'ExportWindows')) {
        $profileRoot = Join-Path $root 'build/godot-profile'
        $env:APPDATA = Join-Path $profileRoot 'Roaming'
        $env:LOCALAPPDATA = Join-Path $profileRoot 'Local'
        New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    }
    switch ($Task) {
        'Editor' { & $godot --path $root --editor }
        'Run' { & $godot --path $root }
        'CheckLocalisation' {
            & $Python tools/localisation.py
        }
        'Test' {
            & $Python tools/localisation.py
            if ($LASTEXITCODE -ne 0) { throw 'Localisation catalogue checks failed.' }
            & $Python tests/localisation_catalogue_test.py
            if ($LASTEXITCODE -ne 0) { throw 'Localisation validation tests failed.' }
            & node tests/localisation_web_test.js
            if ($LASTEXITCODE -ne 0) { throw 'Browser localisation checks failed.' }
            & node tests/content_cache_test.js
            if ($LASTEXITCODE -ne 0) { throw 'Browser asset cache checks failed.' }
            & node tests/loading_handoff_test.js
            if ($LASTEXITCODE -ne 0) { throw 'Loading handoff checks failed.' }
            & $godot --headless --path $root --editor --import
            if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
            $report = Join-Path $root 'build/probe-results.json'
            Invoke-GodotTest @('--headless', '--path', $root, 'res://main.tscn', '--', '--probe-test', "--save-path=$root/build/probe-save.json", "--report=$report") 'Probe'
            $result = Get-Content -LiteralPath $report | ConvertFrom-Json
            if (-not $result.passed) { throw 'Probe checks failed.' }
			Invoke-GodotTest @('--headless', '--path', $root, '--script', 'res://tests/foundation_test.gd') 'Foundation'
			$missionSuites = @('localisation', 'accessibility', 'input_bindings', 'gameplay_bindings', 'audio_settings', 'settings_menu', 'title_audio', 'native_loading', 'level_loading', 'mission1_audio', 'mission3_audio', 'mission1_polish', 'controller_menu', 'diary_pages', 'mission1_ending', 'pocket_watch', 'mission1_rooms', 'presentation_fixes', 'mission2_layout', 'mission2_entry', 'mission2_presentation', 'mission3_layout', 'mission3_presentation', 'mission3_entry', 'mission1_chandelier', 'mission1_steam', 'mission1_route', 'mission1_poison_schedule', 'mission1_walking', 'mission1_save', 'mission1_authoring', 'mission1_authoring_ui', 'mission1_authoring_playthrough', 'mission1_play', 'mission1_revision', 'mission1_life', 'mission1_dialogue', 'mission1_hospitality', 'mission1_playtest', 'mission1_improvements', 'mission1_round3', 'mission1_round4', 'action_menu', 'touch_controls')
			foreach ($suite in $missionSuites) {
				if ($Suites.Count -gt 0 -and $suite -notin $Suites) { continue }
				$frameLimit = if ($suite -in @("title_audio", "mission1_polish", "controller_menu", "diary_pages", "level_loading")) { 2400 } else { 300 }
				Invoke-GodotTest @('--headless', '--path', $root, '--script', "res://tests/$($suite)_test.gd", '--quit-after', "$frameLimit") $suite
			}
			Invoke-GodotTest @('--headless', '--path', $root, '--script', 'res://tests/pause_editor_test.gd') 'Shared pause editor'
        }
        'ExportWeb' {
            New-Item -ItemType Directory -Force build/web | Out-Null
            & $Python tools/export_web.py $godot
        }
        'ExportWindows' {
            New-Item -ItemType Directory -Force build/windows | Out-Null
            & $godot --headless --path $root --export-release Windows build/windows/Amelia.exe
            Copy-Item -LiteralPath assets/audio/mission_3/CREDITS.txt -Destination build/windows/audio-credits.txt
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
    Pop-Location
}
