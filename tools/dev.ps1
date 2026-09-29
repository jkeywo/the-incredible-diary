param(
    [ValidateSet('Editor', 'Run', 'Test', 'ExportWeb', 'ExportWindows')]
    [string]$Task = 'Editor'
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
        'Test' {
            & $godot --headless --path $root --editor --import
            if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
            $report = Join-Path $root 'build/probe-results.json'
            & $godot --headless --path $root res://main.tscn -- --probe-test "--save-path=$root/build/probe-save.json" "--report=$report"
            if ($LASTEXITCODE -ne 0) { throw 'Probe execution failed.' }
            $result = Get-Content -LiteralPath $report | ConvertFrom-Json
            if (-not $result.passed) { throw 'Probe checks failed.' }
			& $godot --headless --path $root --script res://tests/foundation_test.gd
			if ($LASTEXITCODE -ne 0) { throw 'Foundation checks failed.' }
			$missionSuites = @('audio_settings', 'pocket_watch', 'mission1_rooms', 'mission1_chandelier', 'mission1_steam', 'mission1_route', 'mission1_walking', 'mission1_save', 'mission1_play', 'mission1_revision', 'mission1_life', 'mission1_dialogue', 'mission1_hospitality', 'action_menu')
			foreach ($suite in $missionSuites) {
				$output = & $godot --headless --path $root --script "res://tests/$($suite)_test.gd" --quit-after 300 2>&1
				$output | Write-Output
				if ($LASTEXITCODE -ne 0 -or ($output -join "`n") -match 'SCRIPT ERROR|Assertion failed' -or ($output -join "`n") -notmatch 'PASS|"passed":true') { throw "Mission suite failed: $suite" }
			}
			& $godot --headless --path $root --script res://tests/pause_editor_test.gd
			if ($LASTEXITCODE -ne 0) { throw 'Shared pause editor checks failed.' }
        }
        'ExportWeb' {
            New-Item -ItemType Directory -Force build/web | Out-Null
            & $godot --headless --path $root --export-release Web build/web/index.html
        }
        'ExportWindows' {
            New-Item -ItemType Directory -Force build/windows | Out-Null
            & $godot --headless --path $root --export-release Windows build/windows/Amelia.exe
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
} finally { Pop-Location }
