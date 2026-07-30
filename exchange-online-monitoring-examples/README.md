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

Default limits:

- Report period: last 7 days (D7).

How to use it:

- Set the tenant id, app client id, Datadog API key, and Datadog site if needed.
- Run it once per day or once per week.
- Keep the output focused on the report slices the customer actually cares about.

What `exchange-reports.ps1` sends to Datadog:

- An Exchange report summary that can be graphed or queried in Datadog.
- A report event for dashboarding or alerting.

Default limits:

- Report period: last 7 days (D7).

How to use it:

- Set the tenant id, app client id, Datadog API key, and Datadog site if needed.
- Run it on a daily cadence unless the customer asks for something different.
- Keep the data set small and report-focused.

### exchange-mailflow

This folder contains the Exchange Online mail-flow examples. These are the most operationally sensitive scripts in the set because message trace can become large very quickly in a big tenant.

Files:

- `mailflow-datadog-collector.ps1` - the broader Exchange Online trace collector that sends results to Datadog logs.
- `probe-marker-template.ps1` - sends a probe marker event to Datadog.
- `pilot-trace-rollup.ps1` - pulls a narrow trace window and publishes a summary event to Datadog.
- `trace-failure-sampler.ps1` - captures only failures, deferred messages, and a small sample of trace details, then sends them to Datadog.
- `probe-latency-check.ps1` - checks whether the approved synthetic probe was seen and publishes the result to Datadog.

Default limits for `mailflow-datadog-collector.ps1`:

- Lookback window: 15 minutes.
- Max traces per run: 500.

Note on increasing ResultSize: The script calls `Get-MessageTraceDetailV2` once per failed, pending, or deferred message on top of the initial trace pull. Increasing ResultSize significantly on a busy tenant can mean hundreds of additional API round trips, throttling risk, and execution times that exceed the limits of Azure Automation or Azure Functions. Validate run time and throttling behavior before increasing.

What `mailflow-datadog-collector.ps1` sends to Datadog:

- Raw Exchange Online message trace logs and detail records.
- Failed, pending, and deferred trace enrichment for dashboards and alerts.

What `probe-marker-template.ps1` sends to Datadog:

- A probe marker event with the intended send time and correlation id.
- The marker is a Datadog event, not a local file.

Why probe markers exist:

- They give the synthetic probe a unique identity so Datadog can tie the send event to the later mail-flow result.
- They provide a clear start time for latency measurement.
- They make it easy to alert when the expected probe never appears or takes too long.
- They keep synthetic testing separate from normal production mail traffic.

Default limits for `pilot-trace-rollup.ps1`:

- Lookback window: 10 minutes.
- Max traces per run: 2000.

What `pilot-trace-rollup.ps1` sends to Datadog:

- A trace rollup with counts by status and common sender and recipient domains.
- A summary event that shows the scale of the trace window.

Default limits for `trace-failure-sampler.ps1`:

- Lookback window: 15 minutes.
- Max failure records per run: 100.

What `trace-failure-sampler.ps1` sends to Datadog:

- A limited sample of failed, deferred, or pending traces.
- Enriched troubleshooting records that can back dashboards and alerts.

Default limits for `probe-latency-check.ps1`:

- Lookback window: 30 minutes.

What `probe-latency-check.ps1` sends to Datadog:

- A probe-latency record showing whether the probe was found and what the latency was.
- An event that can back a Datadog alert or dashboard tile.

How to use the mail-flow scripts:

- Keep time windows short at first.
- Prefer the rollup or failure sampler before using the broader collector.
- Use Datadog to store the results instead of local files.

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
