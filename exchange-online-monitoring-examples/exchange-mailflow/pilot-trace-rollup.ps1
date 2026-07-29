# Pilot trace rollup example
#
# Purpose:
# - Pull a narrow Exchange Online message trace window.
# - Reduce raw traces into a small summary that is safe for a large tenant.
# - Publish the result to Datadog instead of writing a local file.
#
# How to use:
# 1. Replace the placeholder tenant and auth values.
# 2. Start with a short lookback window, such as 5 to 15 minutes.
# 3. Review the Datadog event before increasing the lookback.
# 4. Increase the lookback only after you know the volume is manageable.

param(
    [string]$Organization = "contoso.onmicrosoft.com",
    [string]$AppId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [int]$LookbackMinutes = 10,
    [int]$MaxTraces = 2000,
    [string]$DatadogApiKey = "<datadog-api-key>",
    [string]$DatadogLogEndpoint = "https://http-intake.logs.datadoghq.com/api/v2/logs"
)

Import-Module ExchangeOnlineManagement

. "$PSScriptRoot\..\send-datadog-log.ps1"

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
    -ResultSize $MaxTraces

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
    record_type = "exchange_mailflow_rollup"
    organization = $Organization
    window_start_utc = $start.ToUniversalTime().ToString('o')
    window_end_utc = $end.ToUniversalTime().ToString('o')
    trace_count = @($traces).Count
    by_status = @($summary)
    top_sender_domains = @($senderDomains)
    top_recipient_domains = @($recipientDomains)
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($result)

[pscustomobject]@{
    trace_count = @($traces).Count
    datadog = $DatadogLogEndpoint
} | Format-List

Disconnect-ExchangeOnline -Confirm:$false
