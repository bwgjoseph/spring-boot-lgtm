param(
    [string]$Title = "Isolated Lanes Observability Test Report",
    [hashtable]$Summary = @{},
    [array]$Lanes = @{},
    [string]$OutputPath = "verification/reports/latest-report.html"
)

$totalPass = 0
$totalFail = 0
foreach ($lane in $Lanes) {
    if ($lane.Status -eq "PASS") { $totalPass++ } else { $totalFail++ }
}
$overallStatus = if ($totalFail -eq 0 -and $totalPass -gt 0) { "PASS" } else { "FAIL" }
$statusColor = if ($overallStatus -eq "PASS") { "#10b981" } else { "#ef4444" }
$statusBg = if ($overallStatus -eq "PASS") { "#ecfdf5" } else { "#fef2f2" }

$lanesHtml = ""
foreach ($lane in $Lanes) {
    $laneBadgeClass = if ($lane.Status -eq "PASS") { "badge-pass" } else { "badge-fail" }
    $itemsHtml = ""
    foreach ($item in $lane.Checks) {
        $itemBadge = if ($item.Status -eq "PASS") { "<span class='badge badge-pass'>PASS</span>" } else { "<span class='badge badge-fail'>FAIL</span>" }
        $details = [System.Web.HttpUtility]::HtmlEncode($item.Details)
        $itemsHtml += @"
        <tr>
            <td style="font-weight: 600;">$($item.Name)</td>
            <td style="text-align: center;">$itemBadge</td>
            <td><code>$details</code></td>
        </tr>
"@
    }

    $lanesHtml += @"
    <div class="card">
        <div class="card-header">
            <div class="lane-title">
                <span class="lane-index">$($lane.Index)</span>
                <div>
                    <h3>$($lane.Name)</h3>
                    <p class="lane-desc">$($lane.Description)</p>
                </div>
            </div>
            <div style="display:flex; align-items:center; gap: 12px;">
                <span class="lane-ram"><i class="icon">💾</i> Peak RAM: $($lane.PeakRAM)</span>
                <span class="badge $laneBadgeClass">$($lane.Status)</span>
            </div>
        </div>
        <div class="card-body">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 30%;">Validation Target</th>
                        <th style="width: 15%; text-align: center;">Result</th>
                        <th style="width: 55%;">Telemetry / Execution Evidence</th>
                    </tr>
                </thead>
                <tbody>
                    $itemsHtml
                </tbody>
            </table>
        </div>
    </div>
"@
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <style>
        :root {
            --bg: #0f172a;
            --surface: #1e293b;
            --surface-border: #334155;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent-green: #10b981;
            --accent-red: #ef4444;
            --accent-blue: #38bdf8;
            --code-bg: #090d16;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: var(--bg); color: var(--text-main); padding: 32px; line-height: 1.5; }
        .container { max-width: 1200px; margin: 0 auto; }
        
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid var(--surface-border); }
        .title-group h1 { font-size: 24px; font-weight: 700; color: #fff; }
        .title-group p { font-size: 13px; color: var(--text-muted); margin-top: 4px; }
        
        .overview-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 28px; }
        .stat-card { background: var(--surface); border: 1px solid var(--surface-border); border-radius: 8px; padding: 16px; }
        .stat-label { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-muted); }
        .stat-val { font-size: 22px; font-weight: 700; margin-top: 6px; }
        
        .card { background: var(--surface); border: 1px solid var(--surface-border); border-radius: 10px; margin-bottom: 20px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2); }
        .card-header { padding: 18px 20px; background: rgba(255, 255, 255, 0.02); display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--surface-border); }
        .lane-title { display: flex; align-items: center; gap: 14px; }
        .lane-index { background: #3b82f6; color: #fff; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 700; }
        .lane-title h3 { font-size: 16px; font-weight: 600; color: #f1f5f9; }
        .lane-desc { font-size: 12px; color: var(--text-muted); margin-top: 2px; }
        .lane-ram { font-size: 12px; background: rgba(56, 189, 248, 0.1); color: var(--accent-blue); padding: 4px 10px; border-radius: 6px; font-weight: 600; }
        
        .card-body { padding: 16px 20px; }
        .table { width: 100%; border-collapse: collapse; font-size: 13px; }
        .table th { text-align: left; padding: 10px 12px; color: var(--text-muted); font-weight: 600; border-bottom: 1px solid var(--surface-border); }
        .table td { padding: 12px; border-bottom: 1px solid rgba(255,255,255,0.05); vertical-align: middle; }
        .table tr:last-child td { border-bottom: none; }
        
        code { background: var(--code-bg); color: #38bdf8; padding: 4px 8px; border-radius: 4px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 12px; display: inline-block; max-width: 600px; overflow-x: auto; white-space: pre-wrap; word-break: break-all; }
        
        .badge { display: inline-block; padding: 4px 10px; font-size: 11px; font-weight: 700; border-radius: 9999px; text-transform: uppercase; letter-spacing: 0.5px; }
        .badge-pass { background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); }
        .badge-fail { background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }
        
        .footer { text-align: center; margin-top: 40px; font-size: 12px; color: var(--text-muted); }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="title-group">
                <h1>$Title</h1>
                <p>Run Timestamp: $($Summary.Timestamp) | Environment: $($Summary.Environment) | Total Execution Time: $($Summary.Duration)</p>
            </div>
            <div>
                <span class="badge" style="background: $statusBg; color: $statusColor; font-size: 15px; padding: 8px 18px;">
                    $overallStatus
                </span>
            </div>
        </div>

        <div class="overview-grid">
            <div class="stat-card">
                <div class="stat-label">Lanes Passed</div>
                <div class="stat-val" style="color: var(--accent-green);">$totalPass / $($Lanes.Count)</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Lanes Failed</div>
                <div class="stat-val" style="color: $(if ($totalFail -gt 0) { 'var(--accent-red)' } else { 'var(--text-muted)' });">$totalFail</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Max RAM Ceiling Observed</div>
                <div class="stat-val" style="color: var(--accent-blue);">$($Summary.MaxPeakRAM)</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Memory Budget Allowed</div>
                <div class="stat-val">4.0 GB</div>
            </div>
        </div>

        $lanesHtml

        <div class="footer">
            Generated automatically by Antigravity Isolated Verification Engine &bull; Spring Boot 3.5 LGTM Sandbox
        </div>
    </div>
</body>
</html>
"@

$reportDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

Set-Content -Path $OutputPath -Value $html -Encoding utf8
Write-Host "Report generated at: $OutputPath" -ForegroundColor Green
return $OutputPath
