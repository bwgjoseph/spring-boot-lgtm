$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = "./verification/logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir }
$logFile = "$logDir/e2e_$timestamp.log"
$env:LOG_FILE = $logFile

# Header for the log
Add-Content -Path $logFile -Value "--- E2E Test Run: $timestamp ---`n"

try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Starting E2E Verification Run: $timestamp" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Add-Content -Path $logFile -Value "Starting E2E Verification Run: $timestamp`n"

    # 1. Check Infrastructure
    pwsh -NoProfile -File ./verification/k8s-health.ps1
    if ($LASTEXITCODE -ne 0) { throw "Infrastructure Health Check Failed" }

    # 2. Generate Traffic
    $testId = pwsh -NoProfile -File ./verification/traffic-gen.ps1
    $testId | ForEach-Object { Add-Content -Path $logFile -Value $_ }
    $testId = $testId | Select-Object -Last 1
    
    if (-not $testId) { throw "Failed to generate Test ID" }

    # 3. Verify Data
    pwsh -NoProfile -File ./verification/data-verify.ps1 -testId $testId
} catch {
    $err = "`n[ERROR] Test Suite Aborted: $($_.Exception.Message)"
    Write-Host $err -ForegroundColor Red
    Add-Content -Path $logFile -Value $err
    exit 1
} finally {
    Write-Host "`nFull logs saved to: $logFile" -ForegroundColor Cyan
}
