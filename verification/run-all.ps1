$ErrorActionPreference = "Stop"

# 1. Check Infrastructure
pwsh -File ./verification/k8s-health.ps1
if ($LASTEXITCODE -ne 0) { exit 1 }

# 2. Generate Traffic and capture TestID
$testId = pwsh -File ./verification/traffic-gen.ps1 | Select-Object -Last 1
if (-not $testId) { Write-Error "Failed to generate Test ID"; exit 1 }

# 3. Verify Data
pwsh -File ./verification/data-verify.ps1 -testId $testId
