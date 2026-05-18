# SLO Definitions — Vuln Watch Observability Stack

A Service Level Indicator (SLI) is a measurable metric that reflects the user's experience (e.g., latency, error rate). A Service Level Objective (SLO) is the specific target applied to that measurement (e.g., 99% success rate). An error budget is the acceptable amount of unreliability derived directly from the SLO target—it defines how much failure is allowed before action must be taken. Together, these definitions form the ultimate contract between the engineering team and the users of the service, ensuring reliability expectations are clear and actionable.

---

## SLO 1: Availability

- **SLI:** `avg_over_time(probe_success{job="blackbox-http"}[30d])`
- **SLO Target:** 99.5% of HTTP probes return success over a rolling 30-day window
- **Measurement window:** 30 days rolling
- **Error budget calculation:**
  - Window = 30 days = 43,200 minutes
  - Allowed failures = 0.5% × 43,200 = **216 minutes of downtime per month**
- **Reasoning:** The service is a vulnerability monitoring tool. Brief outages are tolerable, but extended unavailability means critical security events may go undetected. A 99.5% target strikes the right balance between reliability investment and our risk profile. A 99.9% target would be appropriate for payment systems, but it is excessive and too costly for this use case.
- **Data source:** Blackbox Exporter probing `https://vuln-watch.hng14.com` and `https://staging.vuln-watch.hng14.com`

---

## SLO 2: Latency

- **SLI:** `histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket{status!~"5.."}[5m]))`
- **SLO Target:** 95% of successful requests complete in under 500ms
- **Measurement window:** 5-minute rolling window evaluated continuously
- **Error budget calculation:**
  - 5% of requests may exceed 500ms
  - At typical traffic of 10 req/s = 600 req/min, budget = 30 slow requests per minute
- **Reasoning:** 500ms is the threshold beyond which users perceive latency as sluggish. The p95 measurement means the slowest 5% of requests are excluded from the calculation. This prevents rare, slow outliers from unnecessarily burning the budget while the service is otherwise perfectly healthy.
- **Data source:** Demo service `flask_http_request_duration_seconds_bucket` metric

---

## SLO 3: Error Rate

- **SLI:** `rate(flask_http_request_total{status=~"5.."}[5m]) / rate(flask_http_request_total[5m])`
- **SLO Target:** 99% of requests succeed (error rate below 1%)
- **Measurement window:** 5-minute rolling window evaluated continuously
- **Error budget calculation:**
  - 1% of requests may fail
  - At 10 req/s = 600 req/min, budget = 6 errors per minute before SLO is breached
- **Reasoning:** A 1% error rate means 1 in 100 user-facing requests fails. For a monitoring dashboard, this is acceptable since users can simply retry. Aiming for an error rate below 0.1% would require near-perfect code quality and is unrealistic for a v1 service.
- **Data source:** Demo service `flask_http_request_total` metric with status label

---

## SLO 4: Infrastructure Saturation

This SLO has no error budget in the traditional sense—it is a threshold-based SLO that triggers preventative action when crossed, rather than a ratio measured over time.

- **CPU SLO:** Sustained CPU utilisation below 80% (warning threshold) and below 90% (critical threshold)
- **Memory SLO:** Sustained memory utilisation below 80% (warning threshold) and below 90% (critical threshold)
- **Disk SLO:** Disk utilisation below 75% (warning threshold) and below 90% (critical threshold)
- **Measurement:** Evaluated over 5-minute windows to prevent alert flapping
- **Reasoning:** These thresholds give the team a 10-percentage-point window between warning and critical states to investigate and respond *before* the service is impacted. Disk utilisation at 90% risks log loss and data corruption—it is a hard stop.

---

## Summary Table

| SLO | Target | Error Budget | Window |
|---|---|---|---|
| Availability | 99.5% probe success | 216 minutes/month | 30 days rolling |
| Latency (p95) | < 500ms | 5% of requests | 5 minutes rolling |
| Error Rate | < 1% errors | 1% of requests | 5 minutes rolling |
| CPU Saturation | < 80% sustained | N/A — threshold based | 5 minutes |
| Memory Saturation | < 80% sustained | N/A — threshold based | 5 minutes |
| Disk Saturation | < 75% sustained | N/A — threshold based | 5 minutes |
