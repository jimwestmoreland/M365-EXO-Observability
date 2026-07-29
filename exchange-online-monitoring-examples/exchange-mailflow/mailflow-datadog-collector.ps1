# Exchange Online mail-flow telemetry collector for Datadog
#
# Integration guidance:
# - Run this from Azure Automation, an Azure Function, a scheduled worker, or another secure job runner.
# - Use Exchange Online app-only authentication with a certificate or managed identity where possible.
# - Do not use stored user credentials for unattended monitoring.
# - Send message trace records to Datadog Logs first, then create Datadog facets for fields such as:
#   status, sender, recipient, message_trace_id, latest_detail_event, organization.
# - Create Datadog monitors for:
#   failed message count above threshold,
#   deferred/pending message spikes,
#   no successful delivered probe messages,
#   recurring failures by recipient domain.
# - For active mail-flow monitoring, add a synthetic probe that sends a test message every N minutes.
#   Then have this collector trace that probe sender/recipient/subject and calculate delivery latency.
# - Important caveat: Get-MessageTraceV2 is useful for message-level mail-flow diagnostics, but it is
#   not a real-time transport event stream. Use small polling windows and account for reporting delay,
#   throttling, and documented query/result limits.
#
# Purpose:
# - Pull recent Exchange Online message trace data.
# - Optionally enrich failed/deferred messages with trace details.
# - Send results to Datadog as logs for dashboards, facets, and monitors.
#
# Prereqs:
# Install-Module ExchangeOnlineManagement
# App-only auth is recommended for automation:
# https://learn.microsoft.com/powershell/exchange/app-only-auth-powershell-v2

param(
    [string]$Organization = "contoso.onmicrosoft.com",
    [string]$AppId = "<entra-app-client-id>",
    [string]$CertificateThumbprint = "<cert-thumbprint>",
    [string]$DatadogApiKey = "<datadog-api-key>",

    # Use the correct Datadog site:
    # US1: https://http-intake.logs.datadoghq.com/api/v2/logs
    # US3: https://http-intake.logs.us3.datadoghq.com/api/v2/logs
    # US5: https://http-intake.logs.us5.datadoghq.com/api/v2/logs
    # EU:  https://http-intake.logs.datadoghq.eu/api/v2/logs
    [string]$DatadogLogEndpoint = "https://http-intake.logs.datadoghq.com/api/v2/logs",

    [int]$LookbackMinutes = 15
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
    -ResultSize 5000

$events = foreach ($trace in $traces) {
    $details = $null

    if ($trace.Status -in @("Failed", "Pending", "Deferred")) {
        try {
            $details = Get-MessageTraceDetailV2 `
                -MessageTraceId $trace.MessageTraceId `
                -RecipientAddress $trace.RecipientAddress
        }
        catch {
            $details = @()
        }
    }

    $traceEvents = @($details | Select-Object -ExpandProperty Event -ErrorAction SilentlyContinue)
    $latestDetail = $details | Sort-Object Date -Descending | Select-Object -First 1

    [pscustomobject]@{
        ddsource = "exchange-online"
        service  = "exchange-mailflow"
        ddtags   = "env:prod,workload:exchange-online,tenant:$Organization,status:$($trace.Status)"
        hostname = "exchange-online"

        message = "Exchange Online message trace: $($trace.Status)"

        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

        organization = $Organization
        start_window_utc = $start.ToUniversalTime().ToString("o")
        end_window_utc   = $end.ToUniversalTime().ToString("o")

        received_utc = if ($trace.Received) { ([datetime]$trace.Received).ToUniversalTime().ToString("o") } else { $null }

        sender = $trace.SenderAddress
        recipient = $trace.RecipientAddress
        subject = $trace.Subject
        status = $trace.Status
        message_trace_id = $trace.MessageTraceId
        message_id = $trace.MessageId

        is_failed = ($trace.Status -eq "Failed")
        is_pending = ($trace.Status -eq "Pending")
        is_deferred = ($trace.Status -eq "Deferred")
        is_delivered = ($trace.Status -eq "Delivered")

        detail_events = $traceEvents
        latest_detail_event = $latestDetail.Event
        latest_detail_action = $latestDetail.Action
        latest_detail_text = $latestDetail.Detail
    }
}

Send-DatadogLog -DatadogApiKey $DatadogApiKey -DatadogLogEndpoint $DatadogLogEndpoint -Records @($events)

Disconnect-ExchangeOnline -Confirm:$false
