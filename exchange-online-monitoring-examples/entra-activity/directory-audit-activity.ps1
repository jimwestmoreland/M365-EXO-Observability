# Directory audit activity example
#
# Purpose:
# - Pull Entra directory audit events such as user, group, role, and app changes.
# - Use this for change tracking and security investigations.
# - Keep the window short and the exported fields minimal.
#
# How to use:
# 1. Replace the tenant and app placeholders.
# 2. Use a short polling window.
# 3. Export only the fields needed for audits and dashboards.
# 4. Add deduplication if you schedule this more than once per hour.

param(
    [string]$TenantId = "<entra-tenant-id>",
    [string]$ClientId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [int]$LookbackMinutes = 60,
    [int]$MaxRecords = 200,
    [string]$DatadogApiKey = "<datadog-api-key>",
    [string]$DatadogLogEndpoint = "https://http-intake.logs.datadoghq.com/api/v2/logs"
)

# Required app permissions typically include AuditLog.Read.All.
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint

. "$PSScriptRoot\..\send-datadog-log.ps1"

$end = Get-Date
$start = $end.AddMinutes(-1 * $LookbackMinutes)

$query = "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits?`$filter=activityDateTime ge $($start.ToUniversalTime().ToString('o')) and activityDateTime le $($end.ToUniversalTime().ToString('o'))&`$top=$MaxRecords"

$audits = @()
try {
    $raw = Invoke-MgGraphRequest -Method GET -Uri $query
    $audits = @($raw.value | ForEach-Object {
        [pscustomobject]@{
            activity_utc = $_.activityDateTime
            activity = $_.activityDisplayName
            category = $_.category
            result = $_.result
            initiated_by = $_.initiatedBy.user.userPrincipalName
            target = ($_.targetResources | Select-Object -First 1).displayName
            correlation_id = $_.correlationId
            logged_by_service = $_.loggedByService
        }
    })
}
catch {
    $audits = @([pscustomobject]@{ error = $_.Exception.Message })
}

# Keep only a small slice for the first rollout.
$audits = @($audits | Select-Object -First $MaxRecords)

$record = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    record_type = "entra_directory_audit"
    window_start_utc = $start.ToUniversalTime().ToString('o')
    window_end_utc = $end.ToUniversalTime().ToString('o')
    record_count = @($audits).Count
    audits = $audits
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($record)

[pscustomobject]@{
    record_count = @($audits).Count
    datadog = $DatadogLogEndpoint
} | Format-List

Disconnect-MgGraph
