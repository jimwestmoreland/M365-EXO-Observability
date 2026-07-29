# Pilot trace rollup example
#
# Purpose:
# - Pull a narrow Exchange Online message trace window.
# - Reduce raw traces into a small summary that is safe for a large tenant.
# - Use this script first when you are validating scope and volume.
#
# How to use:
# 1. Replace the placeholder tenant and auth values.
# 2. Start with a short lookback window, such as 5 to 15 minutes.
# 3. Review the summary output before sending anything to Datadog.
# 4. Increase the lookback only after you know the volume is manageable.

param(
    [string]$Organization = "contoso.onmicrosoft.com",
    [string]$AppId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [int]$LookbackMinutes = 10,
    [int]$MaxTraces = 2000,
    [string]$CheckpointPath = ".\exchange-trace-checkpoint.json",
    [string]$OutputPath = ".\exchange-trace-rollup.json"
)

# Load the Exchange Online module that provides Get-MessageTraceV2.
Import-Module ExchangeOnlineManagement

# Connect with app-only auth so the script can run unattended.
Connect-ExchangeOnline `
    -AppId $AppId `
    -CertificateThumbprint $CertificateThumbprint `
    -Organization $Organization `
    -ShowBanner:$false

# Use a narrow polling window first.
# This reduces duplicate records and keeps the initial pilot from overwhelming Datadog.
$end = Get-Date
$start = $end.AddMinutes(-1 * $LookbackMinutes)

# If a checkpoint exists, move the start time forward so repeated runs do not reprocess the same data.
# This is intentionally simple so the customer can understand the control point.
if (Test-Path $CheckpointPath) {
    try {
        $checkpoint = Get-Content -Path $CheckpointPath -Raw | ConvertFrom-Json
        if ($checkpoint.last_end_utc) {
            $checkpointStart = [datetime]$checkpoint.last_end_utc
            if ($checkpointStart -gt $start) {
                $start = $checkpointStart.AddSeconds(-30)
            }
        }
    }
    catch {
        # If the checkpoint is corrupt, fall back to the requested window.
    }
}

$traces = Get-MessageTraceV2 `
    -StartDate $start `
    -EndDate $end `
    -ResultSize $MaxTraces

# Reduce the raw traces into a small rollup before any further integration.
$summary = $traces |
    Group-Object Status |
    Sort-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            status = $_.Name
            count = $_.Count
        }
    }

$senderDomains = $traces |
    ForEach-Object {
        if ($_.SenderAddress -match '@') { ($_.SenderAddress -split '@')[-1].ToLowerInvariant() }
    } |
    Where-Object { $_ } |
    Group-Object |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    ForEach-Object {
        [pscustomobject]@{
            sender_domain = $_.Name
            count = $_.Count
        }
    }

$recipientDomains = $traces |
    ForEach-Object {
        if ($_.RecipientAddress -match '@') { ($_.RecipientAddress -split '@')[-1].ToLowerInvariant() }
    } |
    Where-Object { $_ } |
    Group-Object |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    ForEach-Object {
        [pscustomobject]@{
            recipient_domain = $_.Name
            count = $_.Count
        }
    }

$result = [pscustomobject]@{
    organization = $Organization
    window_start_utc = $start.ToUniversalTime().ToString('o')
    window_end_utc = $end.ToUniversalTime().ToString('o')
    trace_count = @($traces).Count
    by_status = @($summary)
    top_sender_domains = @($senderDomains)
    top_recipient_domains = @($recipientDomains)
}

# Write a local artifact first so the customer can inspect volume before shipping anything to Datadog.
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath

# Save the checkpoint only after a successful run.
[pscustomobject]@{
    last_end_utc = $end.ToUniversalTime().ToString('o')
} | ConvertTo-Json | Set-Content -Path $CheckpointPath

# Show a concise summary in the console.
$result | Format-List

Disconnect-ExchangeOnline -Confirm:$false
