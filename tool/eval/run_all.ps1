# Runs the whole food-vision accuracy evaluation in one command (Windows, Ollama, Arc GPU).
#
# Usage (from the repo root, in PowerShell):
#   .\tool\eval\run_all.ps1
#   .\tool\eval\run_all.ps1 -DryRun          # prints the planned commands and checks, runs nothing
#   .\tool\eval\run_all.ps1 -Model gemma3n:e4b
#
# Runs, one flutter process per strategy (so a crash or a memory spike only costs one run):
#   nutrition5k_50       (train)    legacy_app, pipeline
#   nutrition5k_holdout  (holdout)  legacy_app, pipeline
#   eval                 (own)      pipeline, only if eval/photos has photos named in eval/labels.json
# Then writes eval/results_summary.md with tool/eval/compare_results.py.
# Expected duration on this PC (Arc iGPU): about 2 to 3 hours. Results: eval/results/ (own photos)
# and eval/datasets/<dataset>/results/, summary in eval/results_summary.md, full log in eval/results/run_all_<stamp>.log.
param(
  [string]$Model = 'gemma3n:e2b',
  [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repo

$OllamaUrl = 'http://localhost:11434'
$MinFreeGb = 4
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $repo 'eval\results'
$logFile = Join-Path $logDir "run_all_$stamp.log"

function Write-Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Write-Note([string]$Text) { Write-Host "   $Text" }
function Write-Warn([string]$Text) { Write-Host "   WARNING: $Text" -ForegroundColor Yellow }
function Write-Bad([string]$Text) { Write-Host "   ERROR: $Text" -ForegroundColor Red }

function Get-OllamaExe {
  $local = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
  if (Test-Path $local) { return $local }
  $cmd = Get-Command ollama -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Test-OllamaUp {
  try {
    $v = Invoke-RestMethod -Uri "$OllamaUrl/api/version" -TimeoutSec 3
    return $v.version
  } catch {
    return $null
  }
}

function Get-FreeRamGb {
  $os = Get-CimInstance Win32_OperatingSystem
  return [math]::Round($os.FreePhysicalMemory / 1MB, 1)
}

function Show-OllamaProcessor([string]$Label) {
  $ollama = Get-OllamaExe
  if (-not $ollama) { Write-Note "$Label : ollama.exe not found"; return }
  $lines = @(& $ollama ps 2>&1)
  $model = $lines | Where-Object { $_ -match '^\s*\S+:\S+' } | Select-Object -First 1
  if (-not $model) {
    Write-Warn "$Label : no model loaded in Ollama (nothing to report)"
    return
  }
  $where = if ($model -match '\bGPU\b') { 'GPU' } elseif ($model -match '\bCPU\b') { 'CPU' } else { 'unknown' }
  Write-Note "$Label : ollama ps -> $where"
  Write-Note ($model.Trim() -replace '\s{2,}', ' | ')
  if ($where -eq 'CPU') { Write-Warn 'the model is on the CPU; the run will be much slower. Check OLLAMA_VULKAN / the Arc driver.' }
}

# Planned runs: strategy, dataset folder, label file.
$runs = @(
  @{ Strategy = 'legacy_app'; Dir = 'eval/datasets/nutrition5k_50';      Set = 'train' },
  @{ Strategy = 'pipeline';   Dir = 'eval/datasets/nutrition5k_50';      Set = 'train' },
  @{ Strategy = 'legacy_app'; Dir = 'eval/datasets/nutrition5k_holdout'; Set = 'holdout' },
  @{ Strategy = 'pipeline';   Dir = 'eval/datasets/nutrition5k_holdout'; Set = 'holdout' }
)

# Own photos: only if at least one photo named in eval/labels.json exists.
$ownLabels = Join-Path $repo 'eval\labels.json'
$ownPhotos = Join-Path $repo 'eval\photos'
$ownMatches = @()
if (Test-Path $ownLabels) {
  $ownEntries = Get-Content $ownLabels -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($e in @($ownEntries)) {
    if ($e.file -and (Test-Path (Join-Path $ownPhotos $e.file))) { $ownMatches += $e.file }
  }
}
if ($ownMatches.Count -gt 0) {
  $runs += @{ Strategy = 'pipeline'; Dir = 'eval'; Set = 'own photos' }
}

Write-Host "run_all.ps1  $(if ($DryRun) { '(DRY RUN: nothing is started, pulled or run)' })"
Write-Host "repo: $repo"
Write-Host "model: $Model"

# 1. Ollama installed?
Write-Step '1. Ollama installed'
$ollama = Get-OllamaExe
$ollamaFound = [bool]$ollama
if ($ollama) { Write-Note "found: $ollama" } else {
  Write-Bad 'Ollama is not installed. Install it with: winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements --silent'
}

# 2. Reachable? Start it if not.
Write-Step '2. Ollama reachable at localhost:11434'
$version = Test-OllamaUp
if ($version) {
  Write-Note "reachable, version $version"
} elseif ($DryRun) {
  Write-Note 'not running now. A real run would start it with OLLAMA_VULKAN=1 and OLLAMA_IGPU_ENABLE=1 (hidden window) and wait for /api/version.'
} elseif (-not $ollamaFound) {
  Write-Bad 'cannot start Ollama, it is not installed.'
} else {
  Write-Note 'not running, starting "ollama serve" in a hidden window (OLLAMA_VULKAN=1, OLLAMA_IGPU_ENABLE=1)'
  $env:OLLAMA_VULKAN = '1'
  $env:OLLAMA_IGPU_ENABLE = '1'
  Start-Process -FilePath $ollama -ArgumentList 'serve' -WindowStyle Hidden | Out-Null
  $waited = 0
  while (-not $version -and $waited -lt 90) {
    Start-Sleep -Seconds 2
    $waited += 2
    $version = Test-OllamaUp
  }
  if ($version) { Write-Note "reachable after ${waited}s, version $version" } else {
    Write-Bad 'Ollama did not answer /api/version within 90 s. Run "ollama serve" in its own window to see the error.'
  }
}
$serverOk = [bool]$version

# 3. Model present?
Write-Step "3. Model $Model present"
$modelOk = $false
if ($ollamaFound -and $serverOk) {
  $listed = @(@(& $ollama list 2>&1) | Where-Object { $_ -match ('^' + [regex]::Escape($Model) + '\s') })
  if ($listed.Count -gt 0) {
    $modelOk = $true
    Write-Note "present: $($listed[0].Trim())"
  } elseif ($DryRun) {
    Write-Note "missing. A real run would ask before running: ollama pull $Model"
  } else {
    Write-Warn "$Model is not pulled (about 7.8 GB for gemma3n:e2b)."
    $answer = Read-Host "Run 'ollama pull $Model' now? [y/N]"
    if ($answer -match '^[yY]') {
      & $ollama pull $Model
      if ($LASTEXITCODE -eq 0) { $modelOk = $true } else { Write-Bad "ollama pull failed ($LASTEXITCODE)" }
    }
  }
} elseif ($DryRun) {
  Write-Note "skipped: needs Ollama running. Checked again on a real run."
}

# 4. Free RAM
Write-Step "4. Free RAM (warn below $MinFreeGb GB)"
$freeGb = Get-FreeRamGb
Write-Note "free: $freeGb GB"
$continue = $true
if ($freeGb -lt $MinFreeGb) {
  Write-Warn "only $freeGb GB free. Gemma models need about 4 GB or more to load without swapping."
  Write-Note 'To free memory: close browsers and other heavy apps; if WSL is running, "wsl --shutdown" frees its RAM; then check Task Manager.'
  if (-not $DryRun) {
    $answer = Read-Host 'Continue anyway? [y/N]'
    $continue = ($answer -match '^[yY]')
  }
}

# 5. Planned runs
Write-Step 'Planned runs (one flutter process each)'
foreach ($r in $runs) {
  $cmd = "`$env:VYRO_EVAL='1'; `$env:VYRO_EVAL_MODEL='$Model'; `$env:VYRO_EVAL_DIR='$($r.Dir)'; `$env:VYRO_EVAL_STRATEGY='$($r.Strategy)'; flutter test --no-pub tool/eval/food_vision_eval_test.dart --timeout none"
  Write-Note "[$($r.Set)] $($r.Strategy) on $($r.Dir)"
  Write-Note "    $cmd"
}
if ($ownMatches.Count -eq 0) {
  Write-Note 'own photos: skipped (no photo in eval/photos matches eval/labels.json)'
} else {
  Write-Note "own photos: $($ownMatches.Count) photo(s) matched in eval/photos"
}
Write-Note 'then: py -I tool/eval/compare_results.py  (writes eval/results_summary.md)'

if ($DryRun) {
  Write-Step 'Dry run finished. Nothing was started, pulled or run.'
  exit 0
}

if (-not $serverOk -or -not $modelOk -or -not $continue) {
  Write-Bad 'Not starting the runs (see the errors above).'
  exit 1
}

# 6. Runs
Write-Step "6. Runs (log: $logFile)"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$status = @()
foreach ($r in $runs) {
  $label = "$($r.Strategy) on $($r.Dir)"
  Write-Host ''
  Write-Host "-- $label  $(Get-Date -Format HH:mm)" -ForegroundColor Cyan
  $env:VYRO_EVAL = '1'
  $env:VYRO_EVAL_MODEL = $Model
  $env:VYRO_EVAL_DIR = $r.Dir
  $env:VYRO_EVAL_STRATEGY = $r.Strategy
  $out = & flutter test --no-pub tool/eval/food_vision_eval_test.dart --timeout none 2>&1
  $code = $LASTEXITCODE
  $out | Out-File -FilePath $logFile -Append -Encoding UTF8
  $out | Select-String -Pattern '^\| |All tests passed|Some tests failed|Exception|skipped \(no photo' | ForEach-Object { Write-Host $_.Line }
  if ($code -eq 0) { $state = 'ok' } else { $state = "FAILED (exit $code)" ; Write-Warn "$label failed, continuing with the next run" }
  $status += "$state  $label"
  Show-OllamaProcessor $label
}
$env:VYRO_EVAL = $null
$env:VYRO_EVAL_DIR = $null
$env:VYRO_EVAL_STRATEGY = $null

# 7. Summary
Write-Step '7. Summary'
& py -I tool/eval/compare_results.py 2>&1 | Tee-Object -FilePath $logFile -Append
Write-Host ''
Write-Host 'Run status:'
$status | ForEach-Object { Write-Host "  $_" }
Write-Host "Summary: $(Join-Path $repo 'eval\results_summary.md')"
Write-Host "Log:     $logFile"
