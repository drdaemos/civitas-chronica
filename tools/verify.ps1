param(
	[int]$Runs = 20,
	[int]$Seed = 12000,
	[string]$GodotConsole = "E:\Apps\Godot\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $GodotConsole -PathType Leaf)) {
	throw "Godot console binary not found: $GodotConsole"
}

function Invoke-GodotCheck {
	param([string[]]$Arguments)

	& $GodotConsole --headless --path $ProjectRoot @Arguments
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

Write-Host "verify: content"
Invoke-GodotCheck @("--script", "res://tools/validate_content.gd")

Write-Host "verify: tests"
Invoke-GodotCheck @("--script", "res://tools/run_tests.gd")

Write-Host "verify: deterministic balance matrix"
Invoke-GodotCheck @(
	"--script", "res://tools/simulate.gd", "--",
	"--suite", "--runs=$Runs", "--seed=$Seed"
)

Write-Host "verify: PASS"
