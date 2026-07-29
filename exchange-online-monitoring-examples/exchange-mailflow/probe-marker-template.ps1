# Probe marker template example
#
# Purpose:
# - Create a small local marker file before a synthetic mail-flow test is sent.
# - Give the probe checker a source of truth for the intended send timestamp.
# - Keep the synthetic probe workflow explicit so the customer can review every step.
#
# How to use:
# 1. Run this script immediately before the approved sender dispatches the probe.
# 2. Use the generated correlation id in the subject line or runbook entry.
# 3. Point `03-probe-latency-check.ps1` at the same marker file.

param(
    [string]$ProbeSender = "probe-sender@contoso.com",
    [string]$ProbeRecipient = "probe-recipient@contoso.com",
    [string]$SubjectPrefix = "XO-HealthCheck",
    [string]$DatadogApiKey = "<datadog-api-key>",
    [string]$DatadogLogEndpoint = "https://http-intake.logs.datadoghq.com/api/v2/logs"
)

. "$PSScriptRoot\..\send-datadog-log.ps1"

$now = Get-Date
$correlationId = [guid]::NewGuid().ToString()
$subjectToken = "$SubjectPrefix-$correlationId"

$record = [pscustomobject]@{
    record_type = "probe_marker"
    correlation_id = $correlationId
    probe_sender = $ProbeSender
    probe_recipient = $ProbeRecipient
    subject_prefix = $SubjectPrefix
    subject_token = $subjectToken
    send_utc = $now.ToUniversalTime().ToString('o')
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($record)

[pscustomobject]@{
    correlation_id = $correlationId
    subject_token = $subjectToken
    send_utc = $now.ToUniversalTime().ToString('o')
    datadog = $DatadogLogEndpoint
} | Format-List
