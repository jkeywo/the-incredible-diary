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
Push-Location $root
try {
    New-Item -ItemType Directory -Force build | Out-Null
    if (-not (Test-Path -LiteralPath build/.gdignore)) {
        New-Item -ItemType File -Path build/.gdignore | Out-Null
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
            & $godot --headless --path $root res://main.tscn -- --probe-test "--save-path=$root/build/probe-save.json" "--report=$report"
            if ($LASTEXITCODE -ne 0) { throw 'Probe execution failed.' }
            $result = Get-Content -LiteralPath $report | ConvertFrom-Json
            if (-not $result.passed) { throw 'Probe checks failed.' }
			& $godot --headless --path $root --script res://tests/foundation_test.gd
			if ($LASTEXITCODE -ne 0) { throw 'Foundation checks failed.' }
			$missionSuites = @('localisation', 'input_bindings', 'gameplay_bindings', 'audio_settings', 'settings_menu', 'title_audio', 'native_loading', 'level_loading', 'mission1_audio', 'mission1_polish', 'controller_menu', 'diary_pages', 'mission1_ending', 'pocket_watch', 'mission1_rooms', 'presentation_fixes', 'mission2_layout', 'mission2_entry', 'mission2_presentation', 'mission3_layout', 'mission3_presentation', 'mission3_entry', 'mission1_chandelier', 'mission1_steam', 'mission1_route', 'mission1_poison_schedule', 'mission1_walking', 'mission1_save', 'mission1_authoring', 'mission1_authoring_ui', 'mission1_authoring_playthrough', 'mission1_play', 'mission1_revision', 'mission1_life', 'mission1_dialogue', 'mission1_hospitality', 'mission1_playtest', 'mission1_improvements', 'mission1_round3', 'mission1_round4', 'action_menu', 'touch_controls')
			foreach ($suite in $missionSuites) {
				if ($Suites.Count -gt 0 -and $suite -notin $Suites) { continue }
				$frameLimit = if ($suite -in @("title_audio", "mission1_polish", "controller_menu", "diary_pages", "level_loading")) { 2400 } else { 300 }
				$output = & $godot --headless --path $root --script "res://tests/$($suite)_test.gd" --quit-after $frameLimit 2>&1
				$output | Write-Output
				if ($LASTEXITCODE -ne 0 -or ($output -join "`n") -match 'SCRIPT ERROR|Assertion failed' -or ($output -join "`n") -notmatch 'PASS|"passed":true') { throw "Mission suite failed: $suite" }
			}
			& $godot --headless --path $root --script res://tests/pause_editor_test.gd
			if ($LASTEXITCODE -ne 0) { throw 'Shared pause editor checks failed.' }
        }
        'ExportWeb' {
            New-Item -ItemType Directory -Force build/web | Out-Null
            & $Python tools/export_web.py $godot
        }
        'ExportWindows' {
            New-Item -ItemType Directory -Force build/windows | Out-Null
            & $godot --headless --path $root --export-release Windows build/windows/Amelia.exe
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
} finally { Pop-Location }
