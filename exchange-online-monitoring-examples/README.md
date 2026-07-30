# Exchange Monitoring Examples

This folder contains example scripts for a large Microsoft 365 tenant. Every script is intended to publish its useful output to Datadog so the customer can visualize, query, and alert on the signals in one place.

The current scripts do not keep local JSON, checkpoint, or marker files. They publish directly to Datadog.

The scripts are grouped by topic so the customer can understand each data source separately and adopt only the parts they actually need.

## Datadog At A Glance

Every script in this folder sends its useful output to Datadog.

- `exchange-mailflow/mailflow-datadog-collector.ps1` sends Exchange message trace logs to Datadog.
- `service-health/service-health.ps1` sends Microsoft 365 service health summaries to Datadog.
- `entra-activity/sign-in-activity.ps1` and `entra-activity/directory-audit-activity.ps1` send Entra activity summaries to Datadog.
- `reports/m365-usage-reports.ps1` and `reports/exchange-reports.ps1` send report summaries to Datadog.
- `exchange-mailflow/probe-marker-template.ps1`, `pilot-trace-rollup.ps1`, `trace-failure-sampler.ps1`, and `probe-latency-check.ps1` also publish events to Datadog so the customer can validate and troubleshoot mail flow directly in Datadog.

## Deployment Model

These examples are designed to run as scheduled or timer-driven jobs in a managed environment. The scripts are not meant to be run once by hand from a laptop and left there.

Good deployment options include:

- Azure Automation runbooks.
- Azure Functions timer-triggered jobs.
- Scheduled tasks on a hardened server or VM.
- Container jobs or other managed batch runners.

Suggested cadence by script type:

- Service health: every 15 to 60 minutes.
- Entra sign-in and directory audit: every 15 to 60 minutes, depending on volume.
- Usage and Exchange reports: daily or weekly.
- Mail flow rollups, failure sampling, and probe checks: every few minutes to every 15 minutes, depending on the signal and tenant size.

General operational guidance:

- Run the scripts in a managed identity or app-only auth context wherever possible.
- Keep the Datadog API key in the deployment environment, not in the script body.
- Treat Datadog as the system of record for dashboards, alerts, and troubleshooting.
- Use the script outputs as scheduled telemetry jobs, not as ad hoc local utilities.

## How To Read This Folder

Start with the folder-level topics below, then open the script inside that topic that matches the question you want to answer.

- Use service health when you want to know whether Microsoft 365 has an active incident or advisory.
- Use Entra activity when you want to see sign-ins or directory changes.
- Use reports when you want trend data and scheduled summaries.
- Use exchange mail flow when you need message trace troubleshooting or synthetic probe checks.

## Script Map

| Script | Use it when you need to answer... | Datadog signal | Default limits |
| --- | --- | --- | --- |
| `service-health/service-health.ps1` | Is Microsoft 365 currently degraded or having an advisory? | Service health summary | All current issues, no cap |
| `entra-activity/sign-in-activity.ps1` | Are sign-ins failing, risky, or trending in a bad direction? | Sign-in activity summary | 60-min window, 200 records |
| `entra-activity/directory-audit-activity.ps1` | What changed in Entra and who changed it? | Directory audit summary | 60-min window, 200 records |
| `reports/m365-usage-reports.ps1` | What are the current Microsoft 365 usage trends? | Usage report summary | Last 7 days (D7) |
| `reports/exchange-reports.ps1` | What are the Exchange reporting trends? | Exchange report summary | Last 7 days (D7) |
| `exchange-mailflow/mailflow-datadog-collector.ps1` | Are message traces failing, pending, or deferred? | Raw mail-flow trace logs | 15-min window, 500 traces (see note) |
| `exchange-mailflow/probe-marker-template.ps1` | Did we intentionally send a synthetic probe? | Probe marker event | Single event per run |
| `exchange-mailflow/pilot-trace-rollup.ps1` | How much mail-flow activity is there at a glance? | Trace rollup summary | 10-min window, 2000 traces |
| `exchange-mailflow/trace-failure-sampler.ps1` | What do the important failure traces look like? | Failure sample records | 15-min window, 100 failures |
| `exchange-mailflow/probe-latency-check.ps1` | Did the synthetic probe arrive, and how long did it take? | Probe latency event | 30-min lookback window |

## Folder Layout

### service-health

This folder holds the script for Microsoft 365 service health status. The data is low volume and high value. It is useful for dashboards, incident awareness, and alerts when Microsoft is already reporting a service issue.

File:

- `service-health.ps1` - connects to Microsoft Graph and pulls current service health issues and advisories.

What it sends to Datadog:

- A service health summary with issue count and issue details.
- A record that can back a dashboard tile or an alert.

When to use it:

- You want to know if Microsoft 365 is currently degraded.
- You want a simple status signal for leadership or the service desk.
- You want to alert on active incidents without dealing with a lot of data.

Required permissions and endpoints:

- Microsoft Graph app permission: `ServiceHealth.Read.All`.
- Entra app registration with a certificate for app-only auth.
- Outbound HTTPS (port 443) to `https://graph.microsoft.com`.
- Outbound HTTPS (port 443) to the Datadog logs intake endpoint.

Default limits:

- No record cap. Pulls all current issues on each run.

How to use it:

- Fill in the tenant id, app client id, Datadog API key, and Datadog site if needed.
- Run it on a short schedule, such as every 15 to 60 minutes.
- Use the output in Datadog for a dashboard tile or a simple alert.

### entra-activity

This folder contains Entra identity and audit examples. These are more useful for investigations and change tracking than for real-time alerting. In a large tenant, these can become noisy quickly, so the scripts are intentionally narrow.

Files:

- `sign-in-activity.ps1` - pulls recent sign-in activity and keeps only a limited set of fields.
- `directory-audit-activity.ps1` - pulls directory audit events such as user, group, role, and app changes.

What `sign-in-activity.ps1` sends to Datadog:

- A compact sign-in activity record for the selected time window.
- The sign-in details needed for investigation, dashboards, and alerts.

Required permissions and endpoints:

- Microsoft Graph app permission: `AuditLog.Read.All`.
- Entra app registration with a certificate for app-only auth.
- Outbound HTTPS (port 443) to `https://graph.microsoft.com`.
- Outbound HTTPS (port 443) to the Datadog logs intake endpoint.

Default limits:

- Lookback window: 60 minutes.
- Max records per run: 200.

How to use it:

- Set the tenant id, app client id, Datadog API key, and Datadog site if needed.
- Start with a short lookback window, such as 15 or 60 minutes.
- Use a small max record limit first.

What `directory-audit-activity.ps1` sends to Datadog:

- A compact directory audit record for the selected time window.
- The audit details needed for investigation, dashboards, and alerts.

Required permissions and endpoints:

- Microsoft Graph app permission: `AuditLog.Read.All`.
- Entra app registration with a certificate for app-only auth.
- Outbound HTTPS (port 443) to `https://graph.microsoft.com`.
- Outbound HTTPS (port 443) to the Datadog logs intake endpoint.

Default limits:

- Lookback window: 60 minutes.
- Max records per run: 200.

How to use it:

- Set the tenant id, app client id, Datadog API key, and Datadog site if needed.
- Use a short polling window.
- Keep the max record count low until you know the data rate.

### reports

This folder contains report-style examples. These are intended for daily or weekly use, not fast polling. They are better for trend dashboards and planning than for immediate troubleshooting.

Files:

- `m365-usage-reports.ps1` - pulls Microsoft 365 usage report data.
- `exchange-reports.ps1` - pulls Exchange-oriented report data.

What `m365-usage-reports.ps1` sends to Datadog:

- A usage-report summary that can be graphed or queried in Datadog.
- A report event for dashboarding or alerting.

Required permissions and endpoints:

- Microsoft Graph app permission: `Reports.Read.All`.
- Entra app registration with a certificate for app-only auth.
- Outbound HTTPS (port 443) to `https://graph.microsoft.com`.
- Outbound HTTPS (port 443) to the Datadog logs intake endpoint.

Default limits:

- Report period: last 7 days (D7).

How to use it:

- Set the tenant id, app client id, Datadog API key, and Datadog site if needed.
- Run it once per day or once per week.
- Keep the output focused on the report slices the customer actually cares about.

What `exchange-reports.ps1` sends to Datadog:

- An Exchange report summary that can be graphed or queried in Datadog.
- A report event for dashboarding or alerting.

Required permissions and endpoints:

- Microsoft Graph app permission: `Reports.Read.All`.
- Entra app registration with a certificate for app-only auth.
- Outbound HTTPS (port 443) to `https://graph.microsoft.com`.
- Outbound HTTPS (port 443) to the Datadog logs intake endpoint.

Default limits:

- Report period: last 7 days (D7).

How to use it:

- Set the tenant id, app client id, Datadog API key, and Datadog site if needed.
- Run it on a daily cadence unless the customer asks for something different.
- Keep the data set small and report-focused.

### exchange-mailflow

This folder contains the Exchange Online mail-flow examples. These are the most operationally sensitive scripts in the set because message trace can become large very quickly in a big tenant.

The mail-flow scripts split into two independent groups: diagnostic scripts that observe production traffic, and probe scripts that test mail flow using a synthetic message.

Required permissions and endpoints for all mail-flow scripts:

- Exchange Online app-only auth: Entra app registration with a certificate and the `Exchange.ManageAsApp` API permission.
- The Entra service principal must be assigned the `Global Reader` or `Exchange Administrator` role, or the `View-Only Audit Logs` role group in Exchange Online.
- Outbound HTTPS (port 443) to `https://outlook.office365.com` (Exchange Online PowerShell remote endpoint).
- Outbound HTTPS (port 443) to `https://graph.microsoft.com` (probe-send.ps1 only).
- Outbound HTTPS (port 443) to the Datadog logs intake endpoint.
- `probe-send.ps1` additionally requires the `Mail.Send` Microsoft Graph app permission on the probe sender account.

#### Diagnostic scripts

These run on a schedule and observe real production message trace data. They do not interact with the probe scripts.

| Script | Purpose | Default limits |
| --- | --- | --- |
| `mailflow-datadog-collector.ps1` | Pulls all trace records and enriches failures | 15-min window, 500 traces |
| `pilot-trace-rollup.ps1` | Summarises trace volume by status and domain | 10-min window, 2000 traces |
| `trace-failure-sampler.ps1` | Captures only failures and deferred messages | 15-min window, 100 failures |

How they relate: use `pilot-trace-rollup.ps1` first to understand volume, then `trace-failure-sampler.ps1` to see what the failures look like, then `mailflow-datadog-collector.ps1` when you need full trace detail. All three publish separate Datadog log events and can run in parallel on different schedules.

`mailflow-datadog-collector.ps1` note: it calls `Get-MessageTraceDetailV2` once per failed, pending, or deferred message. Increasing `ResultSize` significantly on a busy tenant can cause throttling and exceed Azure Automation or Azure Functions execution time limits. Validate before increasing.

#### Probe scripts

These run together in sequence to test whether mail can flow end to end and measure how long it takes. They use a synthetic message that is distinct from production traffic.

| Script | Purpose | What it sends to Datadog |
| --- | --- | --- |
| `probe-marker-template.ps1` | Records intent before the probe is sent | `probe_marker` event with `correlation_id` and `subject_token` |
| `probe-send.ps1` | Sends the actual synthetic email via Microsoft Graph | `probe_send` event confirming the send |
| `probe-latency-check.ps1` | Checks message trace for the probe and measures latency | `exchange_probe_latency` event with delivery result |

Why probe markers exist: without a marker event, Datadog cannot know a test message was intentional, when it was meant to be sent, or how long delivery took. The `correlation_id` in the marker is the common field that links all three events in Datadog.

Full end-to-end probe workflow:

1. Run `probe-marker-template.ps1` - Datadog receives a `probe_marker` event; the console prints the `subject_token`.
2. Run `probe-send.ps1` with that `subject_token` - sends the probe email via Microsoft Graph; Datadog receives a `probe_send` confirmation.
3. Wait a few minutes for Exchange Online message trace to reflect the message.
4. Run `probe-latency-check.ps1` - queries message trace for the probe subject; Datadog receives an `exchange_probe_latency` event.
5. In Datadog, join all three events on `subject_prefix` or `subject_token` to see intent, send confirmation, and delivery result together.

Required permission for `probe-send.ps1`: `Mail.Send` on the probe sender account.

## Deduplication

The time-windowed scripts do not contain built-in deduplication logic. If a scheduled run overlaps with the lookback window of a previous run, the overlapping records will be sent to Datadog again.

**Which scripts are at risk:**

- `mailflow-datadog-collector.ps1` - 15-min lookback, duplicates if runs overlap.
- `trace-failure-sampler.ps1` - 15-min lookback, duplicates if runs overlap.
- `pilot-trace-rollup.ps1` - 10-min lookback, duplicates if runs overlap.
- `sign-in-activity.ps1` - 60-min lookback, higher overlap risk.
- `directory-audit-activity.ps1` - 60-min lookback, higher overlap risk.
- `probe-latency-check.ps1` - 30-min lookback, lower risk since it targets one probe result.

**Which scripts are naturally safe:**

- `service-health.ps1` - always reflects the current state, not a windowed stream. Re-runs send the same snapshot.
- `m365-usage-reports.ps1` and `exchange-reports.ps1` - pull a D7 aggregate summary. Re-runs send the same rollup, not multiplied raw records.
- `probe-marker-template.ps1` - generates a new correlation id on every run, so it only duplicates if run twice by mistake.

**How to handle deduplication:**

Option 1 - Use Datadog log rehydration or pipeline rules to deduplicate on a unique field. Each script includes a natural key that Datadog can use:

- Mail-flow scripts: `message_trace_id`
- Entra sign-in: `correlation_id`
- Directory audit: `correlation_id`
- Probe scripts: `correlation_id`

Option 2 - Align the schedule precisely so the run interval matches the lookback window and runs do not overlap. For example, if `LookbackMinutes` is 15, schedule the job every 15 minutes on the exact minute.

Option 3 - Shorten the lookback window slightly below the run interval to leave a small gap. For example, use a 13-minute lookback on a 15-minute schedule. This accepts a small blind spot but eliminates overlap.

Option 4 - Work with Datadog to configure a log index pipeline that drops duplicate events based on the unique field for each record type.

For a large tenant, option 1 or option 4 is recommended because it keeps the scripts simple and pushes deduplication to the platform where it is easier to manage and audit.

## Scale Guidance

These scripts are designed for a large tenant, so the safest pattern is to start small and only widen the scope after the customer confirms the volume is acceptable.

- Keep time windows short for sign-in, directory audit, and mail-flow examples.
- Prefer summary output over raw export whenever possible.
- Only enrich or sample detail rows when there is a failure or an approved probe.
- Use daily or weekly cadence for report-style scripts.
- Review Datadog ingestion volume before increasing lookback or frequency.

## Prerequisites

The examples assume the customer has approved a non-interactive authentication model and the necessary permissions for each data source.

- ExchangeOnlineManagement module for Exchange Online message trace examples.
- Microsoft Graph access for the service health, Entra activity, and reporting examples.
- App-only authentication or another approved non-interactive auth method.
- Datadog API key and Datadog site for every script in this folder.

## Notes

These scripts are examples and should be adapted to the customer's approved auth model, tenant naming, data retention expectations, and Datadog site.
