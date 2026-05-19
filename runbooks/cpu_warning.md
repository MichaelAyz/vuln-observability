# Alert: CPUWarning

## What Is This Alert?

This alert fires when CPU utilisation on the production server (`3.219.30.122`) exceeds **80% for 5 consecutive minutes**. The `for: 5m` duration filters out momentary spikes — if this alert fires, the system has been under sustained CPU pressure long enough to warrant investigation. At 80%, the server still has headroom before services begin degrading, but the trend needs to be understood and stopped.

## Likely Causes

1. **Runaway process** — a single process has entered an infinite loop or is consuming excessive CPU due to a bug.
2. **Legitimate traffic spike** — a surge in HTTP requests to the demo service or Blackbox probes triggering heavy scraping.
3. **Scheduled background job** — a cron job, backup task, or log rotation process running at the wrong time or taking longer than expected.
4. **OTel Collector batch processing spike** — the collector is flushing a large accumulated batch to Tempo or Loki, causing a temporary CPU burst.
5. **Memory pressure causing swap thrashing** — if available RAM is low, the kernel swapping pages to disk will drive CPU up as a secondary effect.

## First 3 Investigation Steps

**Step 1 — Identify the top CPU consumers:**
```bash
top -bn1 | head -20
```
Look at the `%CPU` column. Identify any process consuming more than 30–40% by itself. Note its PID and command name.

**Step 2 — Get a sorted process list for further confirmation:**
```bash
ps aux --sort=-%cpu | head -10
```
Verify the same process is at the top. Check the `TIME` column — high cumulative CPU time combined with high `%CPU` confirms a runaway process rather than a brief spike.

**Step 3 — Check for errors driving the spike:**
```bash
journalctl --since "10 minutes ago" | grep -i error
```
If a service is crashing and restarting in a tight loop, it will appear here. Look for repeated error messages from the same unit.

## How to Resolve

1. If the offending process is one of the observability stack services (prometheus, loki, grafana, etc.), restart it:
   ```bash
   sudo systemctl restart <service-name>
   ```
2. If the process is a runaway non-critical process, kill it:
   ```bash
   sudo kill -9 <PID>
   ```
3. If it is a legitimate traffic spike that is expected to self-resolve, monitor the `top` output for 5 minutes. If CPU drops below 80% on its own, no further action is needed.
4. If it is a cron job, check the schedule and consider rescheduling it to off-peak hours:
   ```bash
   crontab -l
   sudo crontab -l
   ```

## When to Roll Back and How

CPU warnings do not typically require a rollback. If a recent deployment of the demo service (`demo-service`) caused the CPU spike (correlated via `journalctl -u demo-service`):

```bash
sudo systemctl stop demo-service
# Re-deploy the previous version via the CI/CD pipeline
sudo systemctl start demo-service
```

## When and To Whom to Escalate

- If CPU remains above 80% for more than **30 minutes** with no identifiable cause, escalate to the infrastructure team.
- If the offending process cannot be killed or identified, escalate immediately.
- If `CPUCritical` fires while this alert is still active, treat it as a P1 incident.
- **Contact:** infrastructure team via the `#DevOps-Alerts` Slack channel or the on-call rotation.
