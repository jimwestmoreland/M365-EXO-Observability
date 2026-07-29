# Failure sampler example
#
# Purpose:
# - Capture only failed and deferred traces.
# - Limit the number of detailed records so a large tenant does not flood Datadog.
# - Keep the script focused on troubleshooting signals instead of full trace export.
#
# How to use:
# 1. Set the tenant and auth placeholders.
# 2. Choose a short lookback window.
# 3. Keep the sample size small until you know the volume profile.
# 4. Forward only the resulting sample records to Datadog or a file.

param(
    [string]$Organization = "contoso.onmicrosoft.com",
    [string]$AppId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [int]$LookbackMinutes = 15,
    [int]$MaxFailures = 100,
    [string]$OutputPath = ".\exchange-trace-failures.json"
)

Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline `
    -AppId $AppId `
    -CertificateThumbprint $CertificateThumbprint `
    -Organization $Organization `
    -ShowBanner:$false

$end = Get-Date
$start = $end.AddMinutes(-1 * $LookbackMinutes)

$traces = Get-MessageTraceV2 `
    -StartDate $start `
    -EndDate $end `
    -ResultSize 5000 |
    Where-Object { $_.Status -in @('Failed', 'Deferred', 'Pending') }

# Sort newest first and take only the first N records.
# This prevents one bad period from dumping the entire tenant into the log pipeline.
$sample = $traces |
    Sort-Object Received -Descending |
    Select-Object -First $MaxFailures |
    ForEach-Object {
        [pscustomobject]@{
            organization = $Organization
            timestamp_utc = if ($_.Received) { ([datetime]$_.Received).ToUniversalTime().ToString('o') } else { $null }
            sender = $_.SenderAddress
            recipient = $_.RecipientAddress
            recipient_domain = if ($_.RecipientAddress -match '@') { ($_.RecipientAddress -split '@')[-1].ToLowerInvariant() } else { $null }
            subject = $_.Subject
            status = $_.Status
            message_trace_id = $_.MessageTraceId
            message_id = $_.MessageId
        }
    }

# Only enrich the small sample. The customer can disable this block entirely if detail lookups are too expensive.
$enriched = foreach ($item in $sample) {
    $detailRows = @()
    try {
        $detailRows = Get-MessageTraceDetailV2 `
            -MessageTraceId $item.message_trace_id `
            -RecipientAddress $item.recipient
    }
    catch {
        # If detail lookup fails, keep the base record and move on.
    }

    $latestDetail = $detailRows | Sort-Object Date -Descending | Select-Object -First 1

    [pscustomobject]@{
        organization = $item.organization
        timestamp_utc = $item.timestamp_utc
        sender = $item.sender
        recipient = $item.recipient
        recipient_domain = $item.recipient_domain
        subject = $item.subject
        status = $item.status
        message_trace_id = $item.message_trace_id
        message_id = $item.message_id
        latest_detail_event = $latestDetail.Event
        latest_detail_action = $latestDetail.Action
        latest_detail_text = $latestDetail.Detail
        detail_count = @($detailRows).Count
    }
}

$enriched | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath

# Show only a lightweight summary in the console for quick review.
[pscustomobject]@{
    organization = $Organization
    window_start_utc = $start.ToUniversalTime().ToString('o')
    window_end_utc = $end.ToUniversalTime().ToString('o')
    sampled_records = @($sample).Count
    enriched_records = @($enriched).Count
} | Format-List

Disconnect-ExchangeOnline -Confirm:$false
