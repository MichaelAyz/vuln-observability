# Alert: SLOSlowBurn

## What Is This Alert?

This alert fires when the availability error budget is burning at **5x the sustainable rate over a 6-hour window**. In plain English: over the last 6 hours the service has been consuming error budget 5 times faster than the monthly allocation allows. At this rate, the **entire monthly error budget** will be exhausted in approximately **5 days**. This is not an immediate emergency — users may not even notice the degradation — but it requires **same-day investigation**. If left unaddressed, this slow burn becomes a fast burn, and the budget is gone before the month ends.

**The math:** 5x burn rate means 5 × 0.5% = 2.5% of monthly budget consumed per hour over the last 6 hours. Over 6 hours that is 15% of the monthly budget. Left unchecked for 5 days, the budget reaches 100%.

## Likely Causes

1. **Periodic probe failures at regular intervals** — often caused by a scheduled maintenance window that was not silenced in Alertmanager. The application is taken down for 5 minutes every night, and each of those 5-minute windows consumes budget.
2. **Slightly degraded response times causing intermittent probe timeouts** — the application is slow but not down. Some probes succeed in time, some do not. This pattern appears as a slow, steady burn rather than a sharp spike.
3. **DNS TTL issues** — intermittent DNS resolution failures every few minutes when a TTL expires and the resolver needs to re-query. Some probes hit the gap, some do not.
4. **Flaky upstream dependency** — the application depends on an external API or database that is intermittently slow, causing some requests to take longer than the probe timeout.
5. **CDN cache misses causing periodic slow responses** — after a deployment that busts the CDN cache, uncached requests are slow enough to fail the probe timeout.

## First 3 Investigation Steps

**Step 1 — Query the 6-hour probe success rate from Prometheus:**
```bash
curl -s http://localhost:9090/api/v1/query \
  --data-urlencode 'query=avg_over_time(probe_success{job="blackbox-http"}[6h])' \
  | python3 -m json.tool
```
A value below `0.995` confirms the SLO is being violated. Note the exact value — it tells you how degraded the service has been over the last 6 hours.

**Step 2 — Look for a pattern in the failures using a range query:**
```bash
curl -s http://localhost:9090/api/v1/query_range \
  --data-urlencode 'query=probe_success{job="blackbox-http"}' \
  --data-urlencode "start=$(date -d '6 hours ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode 'step=60' \
  | python3 -m json.tool | grep -A1 '"value"'
```
Look for the pattern: random failures suggest network instability; regular intervals suggest scheduled maintenance or DNS TTL; sustained low values suggest application degradation.

**Step 3 — Check the Grafana Blackbox Exporter dashboard uptime timeline:**
Open the `Blackbox Exporter — Uptime & SSL` dashboard and examine the **Uptime Timeline** panel for the last 6 hours. Visual patterns are much faster to interpret than raw query output.

## How to Resolve

1. **If the pattern is periodic and matches a known maintenance window:**
   - Create an Alertmanager silence for the maintenance window duration.
   - Add the maintenance window to the Alertmanager configuration so future windows are pre-silenced.
2. **If response times are consistently elevated:**
   - Contact the application team to investigate slow upstream dependencies.
   - Check the `HTTP Response Time` panel on the Blackbox dashboard for the p90/p99 trend.
3. **If DNS TTL is the cause:**
   - Contact the DNS provider to verify TTL configuration.
   - Consider increasing TTL if the low TTL is causing frequent re-queries that sometimes fail.
4. **If the pattern is random with no clear cause:**
   - Escalate to the application team for investigation.
   - Document the budget consumed and the time of investigation for the SLO review.

## When to Roll Back and How

Not applicable to the monitoring stack. If a recent deployment correlates with the start of the slow burn (check the DORA dashboard deployment history), the application team should evaluate a rollback.

## When and To Whom to Escalate

- **Investigate within the same business day.** This alert does not require an immediate page, but it does require a response before the end of the working day.
- If the error budget reaches **50% consumed** in the current month (visible on the SLO & Error Budget dashboard), escalate to the team lead per the Error Budget Policy — a feature freeze may be required.
- If the budget reaches **100% consumed**, escalate to the engineering manager immediately.
- If the root cause cannot be identified within the business day, escalate to the application team for joint investigation.
- **Contact:**
  - On-call engineer: `#DevOps-Alerts` Slack (no page required unless budget reaches 50%)
  - Application team: `#dev-team` Slack for application-layer issues
  - Team lead: if budget reaches 50% consumed — per Error Budget Policy
