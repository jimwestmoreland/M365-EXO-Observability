# Exchange Monitoring Examples

This folder is a set of example scripts for a large Microsoft 365 tenant. The scripts are grouped by topic so the customer can understand each data source separately and adopt only the parts they actually need.

The goal is not to create one huge monitoring job. The goal is to split the work into smaller, easier-to-review pieces:

- Service health for platform status.
- Entra activity for identity and directory changes.
- Reports for daily usage-style summaries.
- Exchange mail flow for trace data, troubleshooting, and approved synthetic probes.

## How To Read This Folder

Start with the folder-level topics below, then open the script inside that topic that matches the question you want to answer.

- Use service health when you want to know whether Microsoft 365 has an active incident or advisory.
- Use Entra activity when you want to see sign-ins or directory changes.
- Use reports when you want trend data and scheduled summaries.
- Use exchange mail flow when you need message trace troubleshooting or synthetic probe checks.

## Folder Layout

### service-health

This folder holds the script for Microsoft 365 service health status. The data is low volume and high value. It is useful for dashboards, incident awareness, and alerts when Microsoft is already reporting a service issue.

File:

- service-health.ps1 - connects to Microsoft Graph and pulls current service health issues and advisories.

When to use it:

- You want to know if Microsoft 365 is currently degraded.
- You want a simple status signal for leadership or the service desk.
- You want to alert on active incidents without dealing with a lot of data.

How to use it:

- Fill in the tenant id, app client id, and certificate thumbprint.
- Run it on a short schedule, such as every 15 to 60 minutes.
- Use the output to drive a dashboard tile or a simple alert.
- Keep the output small and do not treat this like a high-volume event source.

What it writes:

- A JSON file with the current issues and a small summary.
- A short console summary with the number of issues found.

### entra-activity

This folder contains Entra identity and audit examples. These are more useful for investigations and change tracking than for real-time alerting. In a large tenant, these can become noisy quickly, so the scripts are intentionally narrow.

Files:

- sign-in-activity.ps1 - pulls recent sign-in activity and keeps only a limited set of fields.
- directory-audit-activity.ps1 - pulls directory audit events such as user, group, role, and app changes.

When to use sign-in-activity.ps1:

- You need to investigate login failures or risky sign-ins.
- You want to trend sign-in volume over a short window.
- You want to look at app, user, IP, and failure information without exporting everything.

How to use sign-in-activity.ps1:

- Set the tenant id, app client id, and certificate thumbprint.
- Start with a short lookback window, such as 15 or 60 minutes.
- Use a small max record limit first.
- Filter or sample before you send anything into Datadog.

What it writes:

- A JSON file with the sampled sign-in records.
- A short console summary with the time window and record count.

When to use directory-audit-activity.ps1:

- You want to see configuration changes in Entra.
- You need evidence for a directory change investigation.
- You want a compact audit trail for user, group, app, or role activity.

How to use directory-audit-activity.ps1:

- Set the tenant id, app client id, and certificate thumbprint.
- Use a short polling window.
- Keep the max record count low until you know the data rate.
- Add deduplication if you run it frequently.

What it writes:

- A JSON file with a small set of audit records.
- A short console summary with the time window and record count.

### reports

This folder contains report-style examples. These are intended for daily or weekly use, not fast polling. They are better for trend dashboards and planning than for immediate troubleshooting.

Files:

- m365-usage-reports.ps1 - pulls Microsoft 365 usage report data.
- exchange-reports.ps1 - pulls Exchange-oriented report data.

When to use m365-usage-reports.ps1:

- You want usage trends across Microsoft 365 services.
- You need a daily summary for consumption, adoption, or capacity review.
- You want reports that are naturally batch-oriented.

How to use m365-usage-reports.ps1:

- Set the tenant id, app client id, and certificate thumbprint.
- Run it once per day or once per week.
- Keep the output focused on the report slices the customer actually cares about.
- Use it for trends, not for near-real-time monitoring.

What it writes:

- A JSON file containing a preview of the usage report output.
- A small console summary with the output file path.

When to use exchange-reports.ps1:

- You want Exchange-related reporting instead of live message trace collection.
- You want a simple scheduled summary for mailbox usage or similar reporting needs.
- You want to avoid turning report collection into a noisy trace pipeline.

How to use exchange-reports.ps1:

- Set the tenant id, app client id, and certificate thumbprint.
- Run it on a daily cadence unless the customer asks for something different.
- Keep the data set small and report-focused.
- Treat this as a reporting workflow, not a diagnostic event stream.

What it writes:

- A JSON file with a preview of the report result.
- A small console summary with the output file path.

### exchange-mailflow

This folder contains the Exchange Online mail-flow examples. These are the most operationally sensitive scripts in the set because message trace can become large very quickly in a big tenant. The examples are separated so the customer can choose the least invasive option first.

Files:

- mailflow-datadog-collector.ps1 - the broader Exchange Online trace collector that sends results to Datadog logs.
- probe-marker-template.ps1 - creates a local marker file before a synthetic probe is sent.
- pilot-trace-rollup.ps1 - pulls a narrow trace window and produces a simple rollup.
- trace-failure-sampler.ps1 - captures only failures, deferred messages, and a small sample of trace details.
- probe-latency-check.ps1 - checks whether the approved synthetic probe was seen and estimates latency using the marker file.

When to use mailflow-datadog-collector.ps1:

- You want the full Datadog logging example.
- You are comfortable with message trace data going into Datadog logs.
- You need a broader troubleshooting collector after the customer has agreed to the design.

How to use mailflow-datadog-collector.ps1:

- Set the tenant, app id, certificate thumbprint, and Datadog API key.
- Keep the lookback window small at first.
- Review the volume in Datadog before broadening the window.
- Prefer this after the customer has already accepted the lower-volume examples.

What it writes:

- It sends JSON logs to Datadog.
- It can enrich failed, pending, and deferred traces with trace details.

When to use probe-marker-template.ps1:

- You want to stage an approved synthetic probe before it is sent.
- You need a simple local marker file to hold the intended send timestamp.
- You want the probe process to be explicit and easy to review.

How to use probe-marker-template.ps1:

- Run it immediately before the approved sender sends the probe.
- Keep the generated correlation id with the test message or runbook.
- Point probe-latency-check.ps1 at the marker file it creates.

What it writes:

- A JSON marker file containing the intended send time and correlation id.

When to use pilot-trace-rollup.ps1:

- You want a first-pass summary before committing to the bigger collector.
- You want to validate how much trace data a short polling window produces.
- You want to understand the distribution of trace statuses without exporting every detail.

How to use pilot-trace-rollup.ps1:

- Set the Exchange Online auth values.
- Start with a short lookback window, such as 5 to 15 minutes.
- Review the rollup locally before sending any data elsewhere.
- Use the checkpoint file so repeated runs do not reprocess the same data.

What it writes:

- A JSON rollup with trace counts by status and the most common sender and recipient domains.
- A checkpoint file that records the end of the last successful run.

When to use trace-failure-sampler.ps1:

- You only want the interesting message trace rows, not the full stream.
- You want a failure-focused troubleshooting sample.
- You want to limit the amount of detail that is sent or stored for a large tenant.

How to use trace-failure-sampler.ps1:

- Set the Exchange Online auth values.
- Choose a narrow lookback window.
- Keep the maximum sample count small.
- Use the detailed enrichment only when you really need it.

What it writes:

- A JSON file containing a limited sample of failed, deferred, or pending traces.
- A short console summary with the sample size.

When to use probe-latency-check.ps1:

- You have already approved synthetic mail flow monitoring.
- You want to check whether the expected probe appears in message trace.
- You want a simple delivery latency estimate tied to the marker file.

How to use probe-latency-check.ps1:

- Run probe-marker-template.ps1 first.
- Send the synthetic message with the expected sender, recipient, and subject prefix.
- Run probe-latency-check.ps1 on a short interval after the probe is sent.
- Alert if the probe does not appear or if the latency is too high.

What it writes:

- A JSON result file showing whether the probe was found and what the latency was.
- A short console summary for the operator.

## Scale Guidance

These scripts are designed for a large tenant, so the safest pattern is to start small and only widen the scope after the customer confirms the volume is acceptable.

- Keep time windows short for sign-in, directory audit, and mail-flow examples.
- Prefer summary output over raw export whenever possible.
- Only enrich or sample detail rows when there is a failure or an approved probe.
- Use daily or weekly cadence for report-style scripts.
- Review Datadog ingestion volume before increasing lookback or frequency.
- For mail flow, prefer the rollup or failure sampler before using the broader collector.

## Prerequisites

The examples assume the customer has approved a non-interactive authentication model and the necessary permissions for each data source.

- ExchangeOnlineManagement module for Exchange Online message trace examples.
- Microsoft Graph access for the service health, Entra activity, and reporting examples.
- App-only authentication or another approved non-interactive auth method.
- Datadog API key only if you plan to forward data into Datadog from the mail-flow collector.

## Notes

These scripts are examples and should be adapted to the customer's approved auth model, tenant naming, data retention expectations, and Datadog site.
