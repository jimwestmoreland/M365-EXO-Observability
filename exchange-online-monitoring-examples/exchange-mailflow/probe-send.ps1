# Probe email sender
#
# Purpose:
# - Send a synthetic probe email via Microsoft Graph so the full probe workflow runs end to end.
# - Run this immediately after probe-marker-template.ps1.
# - Pass the subject_token output from the marker script as SubjectToken.
#
# Required app permission: Mail.Send (delegated or application, depending on tenant policy).
#
# Workflow:
# 1. Run probe-marker-template.ps1 - publishes the marker event to Datadog and outputs SubjectToken.
# 2. Run this script with that SubjectToken - sends the probe email.
# 3. Run probe-latency-check.ps1 - checks message trace and publishes the latency result to Datadog.

param(
    [string]$TenantId = "<entra-tenant-id>",
    [string]$ClientId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [string]$ProbeSender = "probe-sender@contoso.com",
    [string]$ProbeRecipient = "probe-recipient@contoso.com",
    # Pass the subject_token value output by probe-marker-template.ps1.
    [string]$SubjectToken = "XO-HealthCheck-<correlation-id>",
    [string]$DatadogApiKey = "<datadog-api-key>",
    [string]$DatadogLogEndpoint = "https://http-intake.logs.datadoghq.com/api/v2/logs"
)

Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint

. "$PSScriptRoot\..\send-datadog-log.ps1"

$message = @{
    message = @{
        subject = $SubjectToken
        body = @{
            contentType = "Text"
            content = "Synthetic mail-flow probe. Subject token: $SubjectToken"
        }
        toRecipients = @(
            @{ emailAddress = @{ address = $ProbeRecipient } }
        )
    }
    saveToSentItems = $false
}

$sent = $false
try {
    Invoke-MgGraphRequest -Method POST `
        -Uri "https://graph.microsoft.com/v1.0/users/$ProbeSender/sendMail" `
        -Body ($message | ConvertTo-Json -Depth 10) `
        -ContentType "application/json"
    $sent = $true
}
catch {
    Write-Warning "Probe send failed: $($_.Exception.Message)"
}

$record = [pscustomobject]@{
    record_type = "probe_send"
    probe_sender = $ProbeSender
    probe_recipient = $ProbeRecipient
    subject_token = $SubjectToken
    sent_utc = (Get-Date).ToUniversalTime().ToString('o')
    send_succeeded = $sent
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($record)

[pscustomobject]@{
    subject_token = $SubjectToken
    send_succeeded = $sent
    datadog = $DatadogLogEndpoint
} | Format-List

Disconnect-MgGraph
