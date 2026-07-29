# Microsoft 365 usage reports example
#
# Purpose:
# - Pull daily or near-daily usage reports from Microsoft 365.
# - Use these for trends, not for near-real-time alerting.
# - Keep report frequency low because the data is inherently batch-oriented.
#
# How to use:
# 1. Replace the tenant and app placeholders.
# 2. Run once per day or once per week.
# 3. Store the output locally or forward a summary to Datadog.
# 4. Use the report type that matches the customer's license and service plan.

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

# Example usage signals. Choose the report that matches the conversation with the customer.
$reportData = @{}
try {
    $activeUsers = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/reports/getOffice365ActiveUserDetail(period='D7')"
    $mailUsage = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/reports/getMailboxUsageDetail(period='D7')"

    $reportData = [pscustomobject]@{
        active_user_detail_preview = ($activeUsers | Out-String)
        mailbox_usage_detail_preview = ($mailUsage | Out-String)
    }
}
catch {
    $reportData = [pscustomobject]@{
        error = $_.Exception.Message
    }
}

$record = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    record_type = "m365_usage"
    report = $reportData
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($record)

[pscustomobject]@{
    datadog = $DatadogLogEndpoint
} | Format-List

Disconnect-MgGraph
