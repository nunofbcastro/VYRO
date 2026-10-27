# Rebuilds the Nutrition5k labels against the CURRENT assets/nutrition/foods.json.
# Run after another agent adds or renames foods or changes tool/eval_data/nutrition5k_map.json.
# Photos and the train/holdout split are NOT changed (the split is in eval/datasets/nutrition5k/split.json).
#
# Usage (from the repo root):
#   .\tool\eval\refresh_labels.ps1
#   .\tool\eval\refresh_labels.ps1 -Python "C:\path\to\venv\Scripts\python.exe"
#
# Steps:
#   1. build_nutrition5k.py --no-download  (labels + mapping stats from the cache, reuses the manifest selection)
#   2. split_labels.py                      (writes nutrition5k_50 and nutrition5k_holdout labels for the same files)
#   3. flutter test test/eval_labels_test.dart  (every label key must exist in foods.json), unless -SkipTests
param(
  [string]$Python = '',
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repo

# Pillow is needed by the builder. Prefer the venv that has it, else the py launcher.
if (-not $Python) {
  $venv = Join-Path $env:LOCALAPPDATA 'Temp\n5k-venv\Scripts\python.exe'
  if (Test-Path $venv) { $Python = $venv }
}

function Invoke-Py([string[]]$Arguments) {
  if ($Python) { & $Python -I @Arguments } else { & py -I @Arguments }
  if ($LASTEXITCODE -ne 0) { throw "python exited with $LASTEXITCODE for: $($Arguments -join ' ')" }
}

Write-Host '== 1. Rebuild Nutrition5k labels from the cache (no download)'
Invoke-Py @('tool/eval_data/build_nutrition5k.py', '--no-download')

Write-Host '== 2. Write train and holdout labels for the fixed split'
Invoke-Py @('tool/eval/split_labels.py')

if ($SkipTests) {
  Write-Host '== 3. Skipped (-SkipTests)'
} else {
  Write-Host '== 3. Check every label key against assets/nutrition/foods.json'
  flutter test --no-pub test/eval_labels_test.dart
  if ($LASTEXITCODE -ne 0) { throw 'label key check failed: a label key is not in foods.json' }
}
Write-Host 'Done. Next: eval results built on the old labels are stale; rerun the harness if you need them to match.'
