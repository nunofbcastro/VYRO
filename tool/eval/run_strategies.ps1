# Runs food-vision eval strategies one per process against local Ollama.
# Usage (from the repo root, in your own PowerShell window):
#   .\tool\eval\run_strategies.ps1
#   .\tool\eval\run_strategies.ps1 -Strategies pt_prompt,en_names -Dir eval/datasets/nutrition5k_50
param(
  [string[]]$Strategies = @('pt_prompt', 'en_names', 'checklist', 'pipeline', 'sc_inter', 'sc_union', 'regions_only'),
  [string]$Model = 'gemma3n:e2b',
  [string]$Dir = 'eval/datasets/nutrition5k_50'
)

$ollama = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
$env:VYRO_EVAL = '1'
$env:VYRO_EVAL_MODEL = $Model
$env:VYRO_EVAL_DIR = $Dir

foreach ($s in $Strategies) {
  Write-Host "=== $s $(Get-Date -Format HH:mm)"
  $env:VYRO_EVAL_STRATEGY = $s
  flutter test --no-pub tool/eval/food_vision_eval_test.dart --timeout none |
    Select-String -Pattern "^\| $s|Some tests failed|All tests passed|Exception"
  # Shows whether the model ran on the GPU (Vulkan) or fell back to the CPU.
  & $ollama ps | Select-Object -Last 1
}
Write-Host "=== done $(Get-Date -Format HH:mm)"
