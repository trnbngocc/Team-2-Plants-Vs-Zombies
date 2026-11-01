# Runs the user-flow scenarios (plants-vs-zombies/tests/scenario.gd), each in its OWN Godot process so that a real
# application quit can be observed. The leaderboard is in memory only: there is no file to inspect, so the checks
# are the in-game ones plus "the process ended" and "a relaunch starts empty".
#
#   powershell -File tools/run_scenarios.ps1 -Godot "C:\path\Godot_v4.7.2-stable_win64.exe" [-OutDir <dir>]
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$OutDir = (Join-Path $env:TEMP 'pvz_scenarios')
)
$ErrorActionPreference = 'Stop'
$project = Join-Path (Split-Path $PSScriptRoot -Parent) 'plants-vs-zombies'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$failed = 0
$total = 0

function Check($ok, $what) {
    $script:total++
    if ($ok) { Write-Host "  ok    $what" } else { Write-Host "  FAIL  $what" -ForegroundColor Red; $script:failed++ }
}

function Run($mode, [int]$timeoutSec = 300) {
    $out = Join-Path $OutDir "$mode.out.txt"
    $err = Join-Path $OutDir "$mode.err.txt"
    $args = @('--path', $project, '--windowed', '--resolution', '1152x648', '--script', 'res://tests/scenario.gd', '--', $mode, $OutDir)
    $p = Start-Process $Godot -ArgumentList $args -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -NoNewWindow
    $exited = $p.WaitForExit($timeoutSec * 1000)
    if (-not $exited) { $p.Kill() }
    [pscustomobject]@{ Exited = $exited; Out = (Get-Content $out -Raw); Err = (Get-Content $err -Raw) }
}

function ScriptFails($r) { ($r.Err -split "`n" | Where-Object { $_ -match '^FAIL|SCRIPT ERROR' }) }
function Passed($r, $mode) { $r.Out -match "SCENARIO ${mode}: \d+ checks, 0 failures" }

Write-Host "== A: Quit on the main menu closes the application"
$r = Run 'menu_quit' 120
Check $r.Exited 'the application closed by itself'
Check (-not (ScriptFails $r)) 'no script errors'

Write-Host "== B: leaderboard from the main menu (BACK only) and back"
$r = Run 'menu_board' 120
Check (Passed $r 'menu_board') 'all in-game checks passed'
Check (-not (ScriptFails $r)) 'no script errors'

Write-Host "== C: username - keyboard Enter vs TICK, then PLAY"
$r = Run 'username' 180
Check (Passed $r 'username') 'all in-game checks passed'
Check (-not (ScriptFails $r)) 'no script errors'

Write-Host "== D: Victory -> NEXT -> leaderboard -> BACK; old name rejected, new name accepted"
$r = Run 'match_victory' 600
Check (Passed $r 'match_victory') 'all in-game checks passed'
Check (-not (ScriptFails $r)) 'no script errors'

Write-Host "== E: Game Over -> NEXT -> leaderboard -> BACK; old name rejected, new name accepted"
$r = Run 'match_defeat' 300
Check (Passed $r 'match_defeat') 'all in-game checks passed'
Check (-not (ScriptFails $r)) 'no script errors'

Write-Host "== F: Game Over, RESTART, Victory: same entry updated; BACK; old name rejected"
$r = Run 'match_two' 900
Check (Passed $r 'match_two') 'all in-game checks passed'
Check (-not (ScriptFails $r)) 'no script errors'

Write-Host "== F2: Victory, RESTART, Game Over: the entry now holds the Defeat"
$r = Run 'match_two_rev' 1200
Check (Passed $r 'match_two_rev') 'all in-game checks passed'
Check (-not (ScriptFails $r)) 'no script errors'

Write-Host "== G: finished match, NEXT, BACK, menu leaderboard, menu Quit"
$r = Run 'back_only' 300
Check $r.Exited 'the application closed by the menu Quit'
Check (-not (ScriptFails $r)) 'no script errors / failed checks'

Write-Host "== H: relaunch - the leaderboard starts empty"
$r = Run 'fresh_start' 120
Check (Passed $r 'fresh_start') 'all in-game checks passed'
Check ($r.Out -match 'BOARD_COUNT 0') 'zero records after a relaunch'

Write-Host ""
Write-Host "scenarios: $total checks, $failed failures"
if ($failed -gt 0) { exit 1 }
