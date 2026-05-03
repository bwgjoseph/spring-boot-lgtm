param(
    [Parameter(Mandatory=$true)]
    [string]$secretName,
    [Parameter(Mandatory=$true)]
    [string]$keyName
)

$secret = kubectl get secret $secretName -n monitoring -o jsonpath="{.data.$keyName}"
if (-not $secret) {
    Write-Error "Secret $secretName or key $keyName not found."
    exit 1
}

$bytes = [System.Convert]::FromBase64String($secret)
$password = [System.Text.Encoding]::UTF8.GetString($bytes)
Write-Host $password
