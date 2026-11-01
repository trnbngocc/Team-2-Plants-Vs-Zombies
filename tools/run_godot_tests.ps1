# Runs every Godot test script (headless ones and windowed ones) and prints the summary line of each.
#   powershell -File tools/run_godot_tests.ps1 -Godot "C:\path\Godot_v4.7.2-stable_win64.exe" [-OutDir <dir>]
# Scenarios (user flows with real quits) are run separately by tools/run_scenarios.ps1.
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$OutDir = (Join-Path $env:TEMP 'pvz_tests')
)
$project = Join-Path (Split-Path $PSScriptRoot -Parent) 'plants-vs-zombies'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$bad = 0

function RunTest($name, $windowed, $timeoutSec) {
    $out = Join-Path $OutDir "$name.out.txt"
    $err = Join-Path $OutDir "$name.err.txt"
    $a = @('--path', $project)
    if ($windowed) { $a += @('--windowed', '--resolution', '1152x648') } else { $a += '--headless' }
    $a += @('--script', "res://tests/$name.gd")
    if ($windowed) { $a += @('--', (Join-Path $OutDir $name)) }
    $p = Start-Process $Godot -ArgumentList $a -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -NoNewWindow
    if (-not $p.WaitForExit($timeoutSec * 1000)) { $p.Kill(); Write-Host "TIMEOUT $name" -ForegroundColor Red; $script:bad++; return }
    $line = (Get-Content $out | Where-Object { $_ -match '\d+ checks, \d+ failures' } | Select-Object -Last 1)
    $errs = (Get-Content $err | Where-Object { $_ -match 'SCRIPT ERROR|^FAIL' })
    if ((-not $line) -or ($line -notmatch ' 0 failures') -or $errs) { $script:bad++; Write-Host "FAIL  $name : $line" -ForegroundColor Red; $errs | Select-Object -First 5 }
    else { Write-Host "ok    $name : $line" }
}

RunTest 'session_test' $false 120
RunTest 'core_integration_test' $false 300
RunTest 'behaviour_capture' $true 400
RunTest 'final_wave_sequence_test' $true 400
RunTest 'projectile_test' $true 300
RunTest 'throw_capture' $true 300
RunTest 'plants_capture' $true 300
RunTest 'audio_test' $true 300
RunTest 'death_test' $true 560
if ($bad -gt 0) { Write-Host "$bad test(s) failed" -ForegroundColor Red; exit 1 }
Write-Host "all tests passed"
