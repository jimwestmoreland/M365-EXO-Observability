# Service health example
#
# Purpose:
# - Pull Microsoft 365 service health issues and incidents.
# - Keep this lightweight because service health is a small, high-value signal.
# - Use it for dashboard tiles and alerting on active incidents.
#
# How to use:
# 1. Replace the tenant and app placeholders.
# 2. Run on a short schedule, such as every 15 to 60 minutes.
# 3. Ship only the active issues and a small amount of context to Datadog.
# 4. Treat this as a status signal, not a high-volume event stream.

param(
    [string]$TenantId = "<entra-tenant-id>",
    [string]$ClientId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [string]$DatadogApiKey = "<datadog-api-key>",
    [string]$DatadogLogEndpoint = "https://http-intake.logs.datadoghq.com/api/v2/logs"
)

# This example uses Microsoft Graph service communications endpoints.
# Required app permissions typically include ServiceHealth.Read.All or the
# customer-approved equivalent for service announcement access.

Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint

. "$PSScriptRoot\..\send-datadog-log.ps1"

$issues = @()
try {
    # Active service issues and advisories.
    $rawIssues = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    $issues = @($rawIssues.value | ForEach-Object {
        [pscustomobject]@{
            id = $_.id
            title = $_.title
            status = $_.status
            classification = $_.classification
            feature = $_.feature
            feature_group = $_.featureGroup
            last_updated_utc = $_.lastModifiedDateTime
            service = $_.service
        }
    })
}
catch {
    # Keep the example simple: record the failure instead of hiding it.
    $issues = @([pscustomobject]@{
        error = $_.Exception.Message
    })
}

$record = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    record_type = "service_health"
    issue_count = @($issues).Count
    issues = $issues
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($record)

# Show a concise summary for operators.
[pscustomobject]@{
    issue_count = @($issues).Count
    datadog = $DatadogLogEndpoint
} | Format-List

Disconnect-MgGraph
