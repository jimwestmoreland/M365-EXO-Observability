# Entra sign-in activity example
#
# Purpose:
# - Pull recent sign-in activity for troubleshooting and security trending.
# - Keep the time window short because sign-in data can be high volume in large tenants.
# - Filter and sample before forwarding to Datadog.
#
# How to use:
# 1. Replace the tenant and app placeholders.
# 2. Start with a 15-minute or 1-hour window.
# 3. Filter to failed or risky sign-ins first.
# 4. Add only the fields needed for dashboards and incident response.

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

# This is intentionally scoped to a short time window.
# Large tenants can produce a lot of sign-in noise, so start narrow.
$query = "https://graph.microsoft.com/v1.0/auditLogs/signIns?`$filter=createdDateTime ge $($start.ToUniversalTime().ToString('o')) and createdDateTime le $($end.ToUniversalTime().ToString('o'))&`$top=$MaxRecords"

$signIns = @()
try {
    $raw = Invoke-MgGraphRequest -Method GET -Uri $query
    $signIns = @($raw.value | ForEach-Object {
        [pscustomobject]@{
            created_utc = $_.createdDateTime
            user = $_.userPrincipalName
            app = $_.appDisplayName
            ip = $_.ipAddress
            status = $_.status.errorCode
            failure_reason = $_.status.failureReason
            conditional_access_status = $_.conditionalAccessStatus
            risk_state = $_.riskState
            correlation_id = $_.correlationId
        }
    })
}
catch {
    $signIns = @([pscustomobject]@{ error = $_.Exception.Message })
}

# Keep only the most useful records when the tenant is busy.
$sample = @($signIns | Select-Object -First $MaxRecords)

$record = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    record_type = "entra_sign_in_activity"
    window_start_utc = $start.ToUniversalTime().ToString('o')
    window_end_utc = $end.ToUniversalTime().ToString('o')
    record_count = @($sample).Count
    sign_ins = $sample
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($record)

[pscustomobject]@{
    record_count = @($sample).Count
    datadog = $DatadogLogEndpoint
} | Format-List

Disconnect-MgGraph
