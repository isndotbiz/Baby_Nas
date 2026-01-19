$localKey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" -Raw
$localKey = $localKey.Trim()

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('root:74108520'))
$headers = @{
    'Authorization' = "Basic $auth"
    'Content-Type' = 'application/json'
}

$body = @{ sshpubkey = $localKey } | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri 'http://192.168.215.2/api/v2.0/user/id/1' -Method Put -Headers $headers -Body $body
    Write-Host "SSH key added to root user" -ForegroundColor Green
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
