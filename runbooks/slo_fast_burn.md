# Alert: SLOFastBurn

## What Is This Alert?

This alert fires when the availability error budget is burning at **14.4x the sustainable rate over a 1-hour window**. In plain English: the service has been unavailable enough in the last hour that, if this rate continues, the **entire monthly error budget** (216 minutes of allowable downtime in a 99.5% availability SLO over 30 days) will be completely exhausted within approximately **50 hours**. This is the fast burn alert — it is triggered by severe, sustained failures, not gradual degradation. The `for: 5m` duration ensures the alert fires quickly once the threshold is crossed.

**The math:** 1 hour burn window × 14.4x rate = 14.4% of monthly budget consumed in 1 hour. The SLO allows 0.5% downtime per month. Fast burn fires at 14.4 × 0.5% = 7.2% consumed per hour (approximately 15.5 minutes of downtime per hour of failures).

## Likely Causes

1. **Sustained partial outage** — the application is not fully down (which would trigger `ServerDown`) but is failing enough probes to burn budget rapidly. Intermittent connection resets, 502 errors from a reverse proxy, or application errors returning to the Blackbox Exporter.
2. **SSL certificate problems** — certificate not expired but presenting errors (mismatched hostname, self-signed, or intermediate chain missing).
3. **CDN or load balancer instability** — an upstream component in front of the application returning errors that the application itself is not aware of.
4. **Flapping** — the application is coming up and down rapidly. Each down period contributes to burn rate even if individual incidents are short.
5. **DNS instability** — intermittent DNS resolution failures causing some probes to succeed and some to fail.

## First 3 Investigation Steps

**Step 1 — Check the current probe status directly:**
```bash
curl -s "http://localhost:9115/probe?target=https://vuln-watch.hng14.com&module=http_2xx" | grep probe_success
```
`probe_success 1` = currently UP. `probe_success 0` = currently DOWN. If the service is currently UP but this alert fired, it means failures occurred earlier in the 1-hour window.

**Step 2 — Query the current 1-hour success rate from Prometheus:**
```bash
curl -s http://localhost:9090/api/v1/query \
  --data-urlencode 'query=avg_over_time(probe_success{job="blackbox-http"}[1h])' \
  | python3 -m json.tool
```
A value below `0.995` (99.5%) means the SLO is being violated. A value around `0.9` or below means severe degradation is occurring.

**Step 3 — Open the Grafana SLO & Error Budget dashboard** and examine:
- The **burn rate** time series panel for the fast burn trend
- The **error budget remaining** gauge to see total budget impact
- The **uptime timeline** on the Blackbox dashboard for the pattern of failures

## How to Resolve

1. **If `ServerDown` is also firing:** Follow the `server_down` runbook. The fast burn is a consequence of the outage.
2. **If the service appears UP now:** Look at the burn rate trend — the alert may have fired on a now-resolved incident. Verify the burn rate is declining and monitor for recurrence.
3. **If flapping:** Investigate the application for instability. Check the application logs with the application team.
4. **If SSL-related:** Contact the application team immediately. SSL issues do not self-resolve.
5. **Do not silence this alert** without first understanding and addressing the root cause.

## When to Roll Back and How

Not applicable to the monitoring stack. This alert indicates an application-layer issue. The application team owns the resolution.

If a recent deployment caused the degradation, the application team should roll back via their deployment pipeline and confirm that `probe_success` returns to 1 consistently after the rollback.

## When and To Whom to Escalate

- **This is a P1 incident. Page the on-call engineer immediately.**
- At 14.4x burn rate, the monthly error budget could be exhausted in under 2 days.
- If the on-call engineer cannot identify and stop the burn within **30 minutes**, escalate to the engineering manager.
- Contact the application team if the issue is in the application layer (SSL, application errors, deployment issues).
- **Contact:**
  - On-call engineer: `#DevOps-Alerts` Slack + direct page
  - Application team: `#dev-team` Slack
  - Engineering manager: if burn rate is not contained within 30 minutes
