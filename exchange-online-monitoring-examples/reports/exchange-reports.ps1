# Exchange reports example
#
# Purpose:
# - Pull Exchange-oriented reporting signals without exporting raw message trace at scale.
# - Use this for mailbox usage or other scheduled Exchange reporting needs.
# - Keep it separate from service health and identity activity to reduce confusion.
#
# How to use:
# 1. Replace the tenant and app placeholders.
# 2. Run on a daily schedule unless the customer asks for a different cadence.
# 3. Export only the report slices they actually need.
# 4. Avoid turning this into a high-volume trace collector.

param(
    [string]$TenantId = "<entra-tenant-id>",
    [string]$ClientId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [string]$DatadogApiKey = "<datadog-api-key>",
    [string]$DatadogLogEndpoint = "https://http-intake.logs.datadoghq.com/api/v2/logs"
)

# Required app permissions typically include Reports.Read.All.
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint

. "$PSScriptRoot\..\send-datadog-log.ps1"

$report = $null
try {
    # Mailbox usage is a good starter example for Exchange reporting.
    $report = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/reports/getMailboxUsageStorage(period='D7')"
}
catch {
    $report = [pscustomobject]@{
        error = $_.Exception.Message
    }
}

$record = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    record_type = "exchange_report"
    report_preview = ($report | Out-String)
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($record)

[pscustomobject]@{
    datadog = $DatadogLogEndpoint
} | Format-List

Disconnect-MgGraph
