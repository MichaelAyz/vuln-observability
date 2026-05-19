# Post-Incident Review — PIR-001
## SSL Certificate Expiry — vuln-watch.hng14.com
**Date:** 2026-05-18
**Severity:** P1
**Duration:** 47 minutes
**Status:** Resolved

---

## Incident Summary

The SSL certificate for `vuln-watch.hng14.com` expired at 09:00 UTC on 2026-05-18, causing all HTTPS connections to fail with an `SSL_ERROR_RX_RECORD_TOO_LONG` error. The Blackbox Exporter probe detected the failure within 60 seconds, firing the `ServerDown` alert which was received in `#DevOps-Alerts` Slack at 09:03 UTC. Twenty-two minutes later, the `SLOFastBurn` alert fired as the availability error budget began burning at 14.4× the sustainable rate. The certificate was renewed by the application team at 09:30 UTC and fully propagated by 09:47 UTC, at which point all probes returned to success and both alerts resolved. All users who attempted to access `vuln-watch.hng14.com` during the 47-minute window received SSL errors and could not use the service.

---

## Timeline

| Time (UTC) | Event |
|---|---|
| 09:00 | SSL certificate for `vuln-watch.hng14.com` expired |
| 09:01 | Blackbox Exporter probe begins failing — `probe_success = 0` |
| 09:02 | `ServerDown` alert fires in Prometheus after 1-minute `for:` threshold |
| 09:03 | 🔴 `FIRING` alert received in `#DevOps-Alerts` Slack with full structured payload |
| 09:05 | On-call engineer acknowledges alert in Slack |
| 09:08 | Engineer opens [server_down runbook](../runbooks/server_down.md) |
| 09:10 | `curl -v https://vuln-watch.hng14.com` confirms `SSL certificate problem: certificate has expired` |
| 09:12 | `dig vuln-watch.hng14.com` confirms DNS is resolving correctly — SSL is isolated as the cause |
| 09:15 | Application team contacted via `#dev-team` Slack |
| 09:18 | Application team confirms certificate renewal process is starting |
| 09:25 | `SLOFastBurn` alert fires — budget burning at 14.4× rate — second alert received in `#DevOps-Alerts` |
| 09:30 | Certificate renewal initiated by application team via Certbot |
| 09:45 | Certificate renewed and propagated to the server |
| 09:47 | Blackbox probe returns `probe_success = 1` — service restored |
| 09:47 | 🟢 `RESOLVED` alerts received in `#DevOps-Alerts` for both `ServerDown` and `SLOFastBurn` |

---

## Root Cause

The SSL certificate for `vuln-watch.hng14.com` was renewed manually on a calendar-based schedule. The responsible team member missed the renewal reminder because it was stored in a personal calendar that was not shared with the rest of the team. No automated certificate monitoring alert existed in the observability stack — the `probe_ssl_earliest_cert_expiry` metric was visible on the Blackbox Exporter dashboard but had no alert rule configured to fire before expiry. As a result, there was no automated warning before the certificate expired, and the first notification the team received was the `ServerDown` alert fired by the Blackbox probe after the expiry occurred.

---

## Impact

- **Users:** All users attempting to access `vuln-watch.hng14.com` received SSL certificate errors for **47 minutes**. No user data was lost or compromised — the application itself was healthy; only the TLS termination layer was affected.
- **Monitoring:** The `ServerDown` and `SLOFastBurn` alerts fired correctly and were received in Slack within 3 minutes of the failure. The alerting pipeline worked exactly as designed.
- **Error Budget:** Approximately **47 minutes** of availability downtime was incurred. Against a 99.5% SLO with a 30-day window, the total budget is **216 minutes**. This incident consumed **21.7%** (47/216) of the monthly error budget in a single event.
- **DORA Metrics:** No workflow runs were directly affected. MTTR for this incident was 47 minutes, within the 1-hour DORA threshold.

---

## What Went Well

- The `ServerDown` alert fired within **2 minutes** of the certificate expiring — detection was fast.
- The Slack notification arrived with a complete structured payload: alert name, severity, affected host, Grafana dashboard link, and runbook link.
- The on-call engineer followed the [server_down runbook](../runbooks/server_down.md) and correctly isolated SSL as the root cause within 10 minutes using `curl -v`.
- The `SLOFastBurn` alert correctly fired and quantified the error budget impact in real time.
- Both `FIRING` and `RESOLVED` states were successfully delivered to `#DevOps-Alerts`, closing the notification loop cleanly.
- Total time from alert receipt to service restoration was **44 minutes** — within the 1-hour MTTR target.

---

## What Went Wrong

1. **No proactive SSL expiry alert was configured.** The `probe_ssl_earliest_cert_expiry` metric was available in Prometheus and visible on the Blackbox dashboard, but no alert rule existed to fire before the certificate expired. The team had visibility into the data but no automation that used it.
2. **Manual, calendar-based renewal process with no shared ownership.** Certificate renewal depended on a single person's personal calendar. This created a single point of failure in the renewal process.
3. **Application team contact details were not in the runbook.** When the on-call engineer needed to contact the application team, they had to search for the right Slack channel rather than following a documented escalation path.
4. **No Alertmanager silence was pre-configured for maintenance windows.** While not directly related to this incident, the lack of a structured maintenance silence process was noted as a risk — a future planned maintenance event could trigger `ServerDown` spuriously if not silenced in advance.

---

## Action Items

| Action | Owner | Due Date |
|---|---|---|
| Add SSL certificate expiry alert rule firing when `probe_ssl_earliest_cert_expiry < 30 days` | On-call engineer | 2026-05-25 |
| Add application team Slack channel and contact details to `server_down.md` runbook | Team lead | 2026-05-20 |
| Automate certificate renewal using Certbot with cron or systemd timer | Application team | 2026-06-01 |
| Add SSL certificate expiry check to the weekly SLO review checklist | On-call engineer | 2026-05-20 |
| Create a shared team calendar for all certificate expiry dates | Team lead | 2026-05-22 |
| Document Alertmanager silence procedure for planned maintenance windows | On-call engineer | 2026-05-25 |

---

## Blameless Statement

This incident was caused by a process gap, not individual failure. The on-call engineer who missed the renewal reminder was operating within a system that did not provide automated safeguards against human memory lapses. The monitoring stack detected the issue within 2 minutes and the alerting pipeline — Prometheus, Alertmanager, and Slack — worked exactly as designed. Every component performed its role correctly. The gap was the absence of a proactive SSL expiry alert that would have given the team 30 days of warning before the certificate expired. That gap is now closed. The action items above are improvements to the system, not remediation for individual behaviour.
