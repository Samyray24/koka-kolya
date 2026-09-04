$tests = @(
    "res://tests/scenes/headless_smoke_test.gd",
    "res://tests/integration/test_core_foundation.gd",
    "res://tests/integration/test_physics_lab.gd",
    "res://tests/integration/test_ai_arena.gd",
    "res://tests/integration/test_bubble_drone.gd",
    "res://tests/integration/test_vehicle_lab.gd",
    "res://tests/integration/test_tools.gd",
    "res://tests/integration/test_graphics_lab.gd",
    "res://tests/integration/test_skill_manager.gd",
    "res://tests/integration/test_first_playable.gd",
    "res://tests/integration/test_vertical_slice.gd",
    "res://tests/integration/test_save_audio_systems.gd",
    "res://tests/integration/test_campaign_and_highway.gd"
)

$allPassed = $true
$results = @()
$godotExe = "$PSScriptRoot\..\..\tools\godot\Godot_v4.6.3-stable_win64.exe"
if (-not (Test-Path $godotExe)) {
    $godotExe = ".\tools\godot\Godot_v4.6.3-stable_win64.exe"
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "--- TEST RUNNER: KOKA-KOLYA (13 SUITES) ---" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

foreach ($t in $tests) {
    Write-Host "RUNNING: $t ..." -NoNewline
    $output = & $godotExe --headless -s $t 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and -not ($output -match "\[FAIL\]|SCRIPT ERROR")) {
        Write-Host " [PASS]" -ForegroundColor Green
        $results += [PSCustomObject]@{ Test = $t; Status = "PASS" }
    } else {
        Write-Host " [FAIL]" -ForegroundColor Red
        Write-Host $output
        $allPassed = $false
        $results += [PSCustomObject]@{ Test = $t; Status = "FAIL" }
    }
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "QUALITY GATE SUMMARY:" -ForegroundColor Cyan
$results | Format-Table -AutoSize
if ($allPassed) {
    Write-Host "SUCCESS: ALL 13 TEST SUITES PASSED (0 ERRORS)" -ForegroundColor Green
} else {
    Write-Host "FAILURE: ERRORS ENCOUNTERED IN TEST SUITES" -ForegroundColor Red
}
Write-Host "========================================================" -ForegroundColor Cyan
if ($allPassed) { exit 0 } else { exit 1 }