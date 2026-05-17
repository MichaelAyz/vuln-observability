DEVOPS TRACK — Stage 6 Task: Production-Grade Observability — LGTM Stack, DORA Metrics & SLOs

Hi Cool Keeds!

Overview

Each team will be building a production-grade observability and reliability platform from the ground up. This goes beyond simply deploying tools. You are acting as Platform Engineers responsible for defining service reliability standards, tracking engineering performance through DORA metrics, implementing SLI/SLO/Error Budget frameworks, and building a self-service observability stack that other teams could adopt.
Your stack will move beyond “up/down” monitoring into user-centric reliability engineering using the full LGTP Stack (Loki, Grafana, Tempo, Prometheus) to correlate metrics, logs, and traces across your entire system. All alerts must be routed to the #DevOps-Alerts Slack channel with structured, actionable payloads.

Task Breakdown
Part 1: Deploy & Harden the Full LGTM Observability Stack

Set Up the Monitoring Stack
Deploy the complete LGTM Stack:

Prometheus for metrics collection and storage
Loki for log aggregation and querying
Tempo as the distributed tracing backend
Grafana as the unified observability frontend


Deploy Node Exporter for system-level metrics (CPU, RAM, Disk, Network I/O), Blackbox Exporter to probe uptime, HTTP response time, and SSL expiry, and Alertmanager as a dedicated alerting component.
Deploy an OpenTelemetry Collector to ship logs to Loki and receive traces. Instrument at least one service with OpenTelemetry to emit traces to Tempo.
All services must run as systemd services or Docker Compose stacks with automatic restart policies.

Infrastructure as Code: Non-Negotiable
The entire stack must be provisioned using Terraform. No component should require manual configuration to reproduce. This includes Prometheus scrape configs, Loki and Tempo datasource provisioning, Alertmanager routing, Grafana dashboards (JSON/YAML only, never the UI), and all alert rules in version-controlled .yml files. Document the one command needed to bring the full stack up in your README.

Configure Data Collection & Exporters
Connect Prometheus to GitHub Actions as your CI/CD metrics source. Scrape Node Exporter at a 15-second interval and Blackbox Exporter for HTTP probing. Ingest application and system journal logs into Loki via OpenTelemetry Collector. Receive traces in Tempo from your instrumented service. Set and document retention periods for both metrics and logs.

Part 2: Define the Four Golden Signals as SLIs
Before building any dashboard, define what reliability means for your service using the Four Golden Signals:

Latency: How long does it take to serve a request? Distinguish between successful and error request latency.
Traffic: How much demand is the system handling? Requests per second, connections, or jobs processed.
Errors: Rate of failed requests — explicit (5xx), implicit (wrong content), and policy failures (timeouts).
Saturation: How “full” is the service? CPU, memory, disk, and connection pool utilization.
For each signal, write a PromQL expression producing a ratio or rate. These become your SLIs.
Part 3: Define SLOs & Error Budgets
Define Service Level Objectives (SLOs)
For each SLI, define an SLO target. Examples:

Availability SLO: 99.5% of HTTP probes return 2xx over a rolling 30-day window
Latency SLO: 95% of requests complete under 500ms
Error Rate SLO: 99% of requests succeed (non-5xx)
Document the reasoning behind each target.
Calculate and Visualize Error Budgets
Error Budget = (1 - SLO target) x measurement window
Build Grafana panels showing budget remaining (percentage and absolute time) and burn rate. Write an Error Budget Policy in your repository: What happens at 50% consumed? At 100% — feature freeze or reliability sprint? Who owns the decision? How often are SLOs reviewed?

Part 4: DORA Metrics & CI/CD Observability
Build a DORA metrics dashboard visualizing:

Deployment Frequency (DF): How often deployments happen. Classify as Elite, High, Medium, or Low per DORA benchmarks and display the classification on the dashboard.
Lead Time for Changes (LTC): Commit to production, broken into sub-intervals: commit, pipeline trigger, pipeline complete, deployment confirmed.
Change Failure Rate (CFR): Deployments resulting in failure, rollback, or hotfix — raw count and rolling percentage. Alert if CFR exceeds your SLO threshold.
Mean Time to Restore (MTTR): Delta between alert firing and resolution. Document where manual intervention adds time.
Also identify at least 2 examples of toil in your workflow, propose automation strategies, and highlight any you implemented.
Part 5: Build Grafana Dashboards (All Provisioned as Code)
All dashboards must be provisioned via JSON or YAML, never manually configured in the UI.

DORA Metrics Dashboard: Deployment frequency, lead time, CFR, and MTTR with benchmark classification and trend graphs.
SLO & Error Budget Dashboard: SLI vs. SLO gauges, error budget remaining (bar gauge colored by urgency), burn rate time series with fast/slow thresholds, and SLO compliance history (7-day and 30-day).
Node Exporter Dashboard: CPU (total and per-core), memory (used/cached/available), disk I/O, network I/O, and system load averages (1m, 5m, 15m).
Blackbox Exporter Dashboard: Uptime/downtime timeline, HTTP response time (p50, p90, p99), SSL expiration countdown, probe success rate.


Unified Observability Dashboard: Log & Trace Correlation
This is your most important dashboard. A user looking at a metric spike must be able to see the spike in an error rate or latency panel, click through to Loki to see correlated logs from that exact time window, click through to Tempo to find the causing trace, and identify the exact service or endpoint responsible. Configure Grafana derived fields in Loki so trace IDs are clickable and open directly in Tempo. This drill-down is a non-negotiable acceptance criterion.

Part 6: Configure the Alerting System
All alert rules must be in version-controlled .yml files, not in Grafana.
Infrastructure Alerts

CPU:warning above 80% for 5+ minutes, critical above 90% for 10+ minutes, recovery on normalisation
Memory:warning at 80%, critical at 90%, recovery on resolution
Disk:warning at 75%, critical at 90%
Server Downtime: Trigger when Blackbox probe fails for 2+ consecutive minutes, recovery when server returns


SLO Burn Rate Alerts: Multi-Window

Fast Burn (critical): 2% of error budget consumed in 1 hour (14.4x burn rate). Act immediately.
Slow Burn (warning): 5% of error budget consumed in 6 hours (5x burn rate). Needs attention before it escalates.
Include for: durations on all rules to prevent flapping. Every burn rate alert must link to its runbook.
CI/CD Integration: Fire alerts when a deployment pushes CFR above your SLO threshold or when MTTR exceeds your defined maximum.
Routing & Inhibition: Configure Alertmanager with route trees grouped by service and severity. Add inhibition rules to suppress CPU/memory/latency noise when a host is fully unreachable. Document silencing configuration.

Slack Notifications: All alerts route to #DevOps-Alerts. Each payload must include alert name and severity, affected host, current metric value, a Grafana dashboard link, a runbook link, and firing or resolved status. Use structured Alertmanager templates — plain text is not acceptable.

Part 7: Incident Management & Runbooks

Runbooks: For every alert in Part 6, write a Markdown runbook answering: What is this alert? What is the likely cause? What are the first 3 investigation steps? How do I resolve it? Should I roll back and when? When and to whom do I escalate?
Blameless Post-Incident Review (PIR): Simulate or document one incident. Cover the full timeline (detection, response, resolution), root cause, impact, what went wrong in detection or tooling, and action items with owners and due dates.


Part 8: Game Day: Chaos & Failure Simulation
This is not optional.

Scenario 1: Deployment Failure. Trigger a failing GitHub Actions deployment. Observe DORA metrics update, confirm the CFR alert fires in Slack, document the timeline.
Scenario 2: Latency Injection. Simulate high latency. Observe the SLI degrade, burn rate increase, Fast Burn alert fire, and the correlated trace in Tempo. Screenshot every step.
Scenario 3: Resource Pressure. Simulate CPU or memory pressure. Confirm alerts fire in sequence (warning before critical) and recovery alerts send when pressure clears.


:red_circle: Live Presentation
Slide Presentation: Cover LGTM architecture and data flow, the Four Golden Signals with PromQL expressions, the SLI to SLO to Error Budget to Alert pipeline, DORA benchmarks, toil reduction, one-command IaC deployment, Game Day results, and incident management. Include diagrams and screenshots throughout.

Each team member must present their contribution. Walk through the full LGTP deployment and IaC approach, Four Golden Signals SLIs and PromQL expressions, SLO targets and reasoning, error budget dashboard and policy, DORA dashboard with classification, all five Grafana dashboards with live trace drill-down, Alertmanager routing and Slack templates, Game Day results, one runbook read aloud, and the blameless PIR.

Submission Requirements
Blog Post: Cover every part of the setup with screenshots of all dashboards, SLO panels, log and trace correlation, alert rules, Alertmanager config, firing and resolved Slack notifications, all three Game Day scenarios, and a runbook example. Explain why the LGTM stack was chosen over managed alternatives; the philosophy behind SLIs, SLOs, and error budgets; how the Four Golden Signals go beyond CPU/RAM; how DORA metrics connect to business outcomes; how burn rate alerting reduces alert fatigue; and what toil was identified.

GitHub Repository must contain:

Terraform or Docker Compose IaC for the full LGTM stack
prometheus.yml, Alertmanager config, and SLO definitions (version-controlled)
Grafana dashboard JSON/YAML provisioning files
Runbook Markdown files for every alert rule
README.md with the Error Budget Policy, dashboard guide, and one-command deployment instruction


Evidence Screenshots

All LGTM components running (Prometheus, Loki, Tempo, Grafana)
SLO & Error Budget dashboard
DORA metrics dashboard with performance classifications
Node Exporter and Blackbox Exporter dashboards
Unified log & trace correlation drill-down in action
Alert rules in version-controlled .yml files
Alertmanager routing and inhibition configuration
Firing and resolved alerts in #DevOps-Alerts with full structured Slack payload
Screenshot sequence for each Game Day scenario: trigger, degradation, alert, trace, recovery


Reliability Documentation

Four Golden Signals SLI definitions with PromQL expressions
SLO targets with written rationale and error budget calculations
Error Budget Policy document
Runbook for every alert rule (Markdown, version-controlled)
One blameless Post-Incident Review document