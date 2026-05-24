param()

$ErrorActionPreference = "Stop"

$lineConfigFile = Join-Path $PSScriptRoot ".line-config.json"

if (-not (Test-Path -LiteralPath $lineConfigFile)) {
    throw "Missing .line-config.json. Copy .line-config.example.json to .line-config.json first."
}

$config = Get-Content -LiteralPath $lineConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
$channelAccessToken = [string]$config.channelAccessToken
$recipientMode = if ([string]::IsNullOrWhiteSpace([string]$config.recipientMode)) { "broadcast" } else { [string]$config.recipientMode }

if ([string]::IsNullOrWhiteSpace($channelAccessToken)) {
    throw "channelAccessToken is empty in .line-config.json"
}

$body = @{
    messages = @(
        @{
            type = "text"
            text = "Codex LINE test OK`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }
    )
}

$endpoint = "https://api.line.me/v2/bot/message/broadcast"

if ($recipientMode -eq "push") {
    $userId = [string]$config.userId
    if ([string]::IsNullOrWhiteSpace($userId)) {
        throw "recipientMode is 'push' but userId is empty in .line-config.json"
    }

    $endpoint = "https://api.line.me/v2/bot/message/push"
    $body.to = $userId
}
elseif ($recipientMode -ne "broadcast") {
    throw "recipientMode must be 'broadcast' or 'push'"
}

$headers = @{
    "Authorization" = "Bearer $channelAccessToken"
    "Content-Type" = "application/json"
}

Invoke-WebRequest -UseBasicParsing -Method Post -Uri $endpoint -Headers $headers -Body ($body | ConvertTo-Json -Depth 5) | Out-Null
Write-Host "LINE test message sent."
