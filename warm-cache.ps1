$registry = "docker.xyz.dot"
$imageFile = "IMAGES.md"

Write-Host "--- Warming Registry Cache: $registry ---" -ForegroundColor Cyan

# Parse the IMAGES.md table
Get-Content $imageFile | Select-Object -Skip 2 | ForEach-Object {
    # Match the row format: | Component | Container Name | Image:Tag | Registry Source |
    # We look for the Image:Tag column (3rd column)
    if ($_ -match '\|\s\*\*.+\*\*\s\|\s`[^`]+`\s\|\s`([^`]+)`\s\|') {
        $imageAndTag = $matches[1]
        
        # Remove any leading registry prefixes that might be in the image string
        $cleanImage = $imageAndTag -replace '^.*\/', ''
        
        $pullCommand = "docker pull $registry/$cleanImage"
        
        Write-Host "Warming: $registry/$cleanImage" -ForegroundColor Gray
        
        # Execute the pull
        Invoke-Expression $pullCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   -> Success" -ForegroundColor Green
        } else {
            Write-Host "   -> Failed" -ForegroundColor Red
        }
    }
}
