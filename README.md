# M365 EXO Observability Examples

This repository contains example scripts for Microsoft 365 and Exchange Online observability.

The goal is to get all of the resulting signals into Datadog so they can be visualized, queried, and alerted on in one place.

Start here:

- [exchange-online-monitoring-examples](exchange-online-monitoring-examples) - organized example scripts grouped by topic.

The examples are split into these areas:

- Service health
- Entra sign-in and directory audit activity
- Microsoft 365 and Exchange reports
- Exchange mail flow, trace sampling, and synthetic probe checks

The scripts are examples only and should be adapted to the tenant, permissions model, and Datadog setup being used. The intended end state is to forward the useful output into Datadog.

Deployment guidance for the examples is in the folder README. In short, these are meant to run as scheduled jobs or timer-driven jobs in a managed runtime, not as one-off local scripts.