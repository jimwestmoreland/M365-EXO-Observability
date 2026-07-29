# Synthetic probe latency example
#
# Purpose:
# - Look for a known test message and calculate delivery latency.
# - Keep the probe logic separate from the general trace collector.
# - Use this only after the customer approves synthetic mail-flow checks.
#
# How to use:
# 1. Configure the probe sender, recipient, and subject prefix.
# 2. Run the script on a short interval.
# 3. Alert if the probe does not show up in the trace window.
# 4. Use the latency result to decide whether mail flow is healthy.

param(
    [string]$Organization = "contoso.onmicrosoft.com",
    [string]$AppId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [string]$ProbeSender = "probe-sender@contoso.com",
    [string]$ProbeRecipient = "probe-recipient@contoso.com",
    [string]$SubjectPrefix = "XO-HealthCheck",
    [string]$ProbeMarkerPath = ".\exchange-probe-marker.json",
    [int]$LookbackMinutes = 30,
    [string]$OutputPath = ".\exchange-probe-latency.json"
)

Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline `
    -AppId $AppId `
    -CertificateThumbprint $CertificateThumbprint `
    -Organization $Organization `
    -ShowBanner:$false

$end = Get-Date
$start = $end.AddMinutes(-1 * $LookbackMinutes)

$expectedSendUtc = $null
$expectedCorrelationId = $null

# The marker file is written by the step-0 script before the probe is sent.
# This lets the customer measure latency without guessing the intended send time.
if (Test-Path $ProbeMarkerPath) {
    try {
        $marker = Get-Content -Path $ProbeMarkerPath -Raw | ConvertFrom-Json
        if ($marker.send_utc) {
            $expectedSendUtc = [datetime]$marker.send_utc
        }
        $expectedCorrelationId = $marker.correlation_id
    }
    catch {
        # If the marker is missing or corrupt, continue with trace lookup only.
    }
}

# Search a narrow window for the probe path.
# The subject prefix gives the customer a simple way to isolate approved synthetic traffic.
$traces = Get-MessageTraceV2 `
    -StartDate $start `
    -EndDate $end `
    -SenderAddress $ProbeSender `
    -RecipientAddress $ProbeRecipient `
    -ResultSize 5000 |
    Where-Object { $_.Subject -like "$SubjectPrefix*" }

$latest = $traces | Sort-Object Received -Descending | Select-Object -First 1

if ($null -eq $latest) {
    [pscustomobject]@{
        organization = $Organization
        probe_sender = $ProbeSender
        probe_recipient = $ProbeRecipient
        subject_prefix = $SubjectPrefix
        expected_correlation_id = $expectedCorrelationId
        window_start_utc = $start.ToUniversalTime().ToString('o')
        window_end_utc = $end.ToUniversalTime().ToString('o')
        probe_found = $false
        delivery_latency_seconds = $null
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath

    Write-Host "No probe trace found in the window. This is the alert condition to investigate."
    Disconnect-ExchangeOnline -Confirm:$false
    return
}

$receivedUtc = [datetime]$latest.Received
$latencySeconds = $null
if ($expectedSendUtc -and $latest.Received) {
    $latencySeconds = [math]::Round(($receivedUtc.ToUniversalTime() - $expectedSendUtc.ToUniversalTime()).TotalSeconds, 2)
}

[pscustomobject]@{
    organization = $Organization
    probe_sender = $ProbeSender
    probe_recipient = $ProbeRecipient
    subject_prefix = $SubjectPrefix
    expected_correlation_id = $expectedCorrelationId
    window_start_utc = $start.ToUniversalTime().ToString('o')
    window_end_utc = $end.ToUniversalTime().ToString('o')
    probe_found = $true
    status = $latest.Status
    sender = $latest.SenderAddress
    recipient = $latest.RecipientAddress
    message_trace_id = $latest.MessageTraceId
    message_id = $latest.MessageId
    received_utc = ([datetime]$latest.Received).ToUniversalTime().ToString('o')
    delivery_latency_seconds = $latencySeconds
} | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath

# Surface a concise result for a dashboard or runbook.
[pscustomobject]@{
    probe_found = $true
    status = $latest.Status
    received_utc = ([datetime]$latest.Received).ToUniversalTime().ToString('o')
    delivery_latency_seconds = $latencySeconds
} | Format-List

Disconnect-ExchangeOnline -Confirm:$false
