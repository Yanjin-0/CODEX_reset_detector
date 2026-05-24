param(
    [int]$IntervalSeconds = 300,
    [switch]$RunOnce,
    [switch]$NoNotify
)

$ErrorActionPreference = "Stop"

$apiUrl = "https://www.hascodexratelimitreset.today/api/status"
$stateFile = Join-Path $PSScriptRoot ".codex-reset-state.json"
$lineConfigFile = Join-Path $PSScriptRoot ".line-config.json"
$notifyScript = "C:\Users\colac\Desktop\.notify.ps1"

function Get-SavedState {
    if (-not (Test-Path -LiteralPath $stateFile)) {
        return @{
            LastNotifiedResetAt = $null
            LastObservedState = $null
        }
    }

    try {
        $raw = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        return @{
            LastNotifiedResetAt = $raw.LastNotifiedResetAt
            LastObservedState = $raw.LastObservedState
        }
    }
    catch {
        return @{
            LastNotifiedResetAt = $null
            LastObservedState = $null
        }
    }
}

function Save-State([string]$lastObservedState, [object]$lastNotifiedResetAt) {
    $payload = @{
        LastObservedState = $lastObservedState
        LastNotifiedResetAt = $lastNotifiedResetAt
    } | ConvertTo-Json

    Set-Content -LiteralPath $stateFile -Value $payload -Encoding UTF8
}

function Show-DesktopNotification([string]$title, [string]$message) {
    if (Test-Path -LiteralPath $notifyScript) {
        & $notifyScript -Title $title -Message $message -Duration 10
        return
    }

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($message, $title) | Out-Null
}

function Get-LineConfig {
    if (-not (Test-Path -LiteralPath $lineConfigFile)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $lineConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Failed to read $lineConfigFile. Please check its JSON format."
    }
}

function Get-Status {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $apiUrl -Headers @{ "Cache-Control" = "no-cache" }
    return $response.Content | ConvertFrom-Json
}

function Send-LineMessage([string]$message) {
    $lineConfig = Get-LineConfig

    if ($null -eq $lineConfig) {
        throw "Missing .line-config.json"
    }

    $channelAccessToken = [string]$lineConfig.channelAccessToken
    if ([string]::IsNullOrWhiteSpace($channelAccessToken)) {
        throw "channelAccessToken is empty in .line-config.json"
    }

    $recipientMode = [string]$lineConfig.recipientMode
    if ([string]::IsNullOrWhiteSpace($recipientMode)) {
        $recipientMode = "broadcast"
    }

    $headers = @{
        "Authorization" = "Bearer $channelAccessToken"
        "Content-Type" = "application/json"
    }

    $body = @{
        messages = @(
            @{
                type = "text"
                text = $message
            }
        )
    }

    $endpoint = "https://api.line.me/v2/bot/message/broadcast"

    if ($recipientMode -eq "push") {
        $to = [string]$lineConfig.userId
        if ([string]::IsNullOrWhiteSpace($to)) {
            throw "recipientMode is 'push' but userId is empty in .line-config.json"
        }

        $endpoint = "https://api.line.me/v2/bot/message/push"
        $body.to = $to
    }
    elseif ($recipientMode -ne "broadcast") {
        throw "recipientMode must be 'broadcast' or 'push'"
    }

    Invoke-WebRequest -UseBasicParsing -Method Post -Uri $endpoint -Headers $headers -Body ($body | ConvertTo-Json -Depth 5) | Out-Null
}

function Build-NotificationMessage($status) {
    $subtitle = if ($status.yesSubtitles -and $status.yesSubtitles.Count -gt 0) {
        $status.yesSubtitles[0]
    }
    else {
        "Codex rate limit reset."
    }

    $tweetUrl = if ($status.automationSummary -and $status.automationSummary.tweetUrl) {
        [string]$status.automationSummary.tweetUrl
    }
    else {
        "https://www.hascodexratelimitreset.today/"
    }

    return "Codex reset: YES`n$subtitle`n$tweetUrl"
}

Write-Host "Watching $apiUrl every $IntervalSeconds seconds..."

$savedState = Get-SavedState

while ($true) {
    try {
        $status = Get-Status
        $currentState = [string]$status.state
        $currentResetAt = if ($null -ne $status.resetAt) { [string]$status.resetAt } else { $null }
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        Write-Host "[$timestamp] state=$currentState"

        $hasTransitionToYes =
            $savedState.LastObservedState -eq "no" -and
            $currentState -eq "yes" -and
            $currentResetAt -ne $savedState.LastNotifiedResetAt

        if ($hasTransitionToYes -and -not $NoNotify) {
            $message = Build-NotificationMessage -status $status

            Send-LineMessage -message $message
            Show-DesktopNotification -title "Codex reset: YES" -message "LINE notification sent."

            $savedState.LastNotifiedResetAt = $currentResetAt
        }

        $savedState.LastObservedState = $currentState
        Save-State -lastObservedState $savedState.LastObservedState -lastNotifiedResetAt $savedState.LastNotifiedResetAt
    }
    catch {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Warning "[$timestamp] Check failed: $($_.Exception.Message)"
    }

    if ($RunOnce) {
        break
    }

    Start-Sleep -Seconds $IntervalSeconds
}
