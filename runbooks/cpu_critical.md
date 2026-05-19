# Alert: CPUCritical

## What Is This Alert?

This alert fires when CPU utilisation on the production server exceeds **90% for 10 consecutive minutes**. The `for: 10m` duration confirms this is not a transient spike but a sustained crisis. At 90% CPU, the kernel scheduler is starved — services will begin queuing requests, response times will balloon, and Prometheus scrapes may start timing out. **This is a P1 incident. Act immediately.**

## Likely Causes

1. **Runaway process in an infinite loop** — a bug in application code, a broken cron script, or a zombie process consuming all available cycles.
2. **OOM condition causing swap-induced CPU thrash** — if memory is also exhausted, the kernel spends all CPU time moving pages between RAM and swap disk.
3. **Fork bomb or process explosion** — a script spawning thousands of child processes, visible as a massive `Tasks` count in `top`.
4. **Loki or Prometheus compaction spike** — TSDB compaction or Loki chunk flushing under high ingest pressure.
5. **Sustained traffic surge** — legitimate but unexpected traffic volume overwhelming the demo service.

## First 3 Investigation Steps

**Step 1 — Identify the top CPU consumer immediately:**
```bash
top -bn1 | head -20
```
Look at the `%CPU` column. A single process above 80% is a runaway. Multiple processes all elevated suggests a fork bomb or swap thrashing.

**Step 2 — Check the process list sorted by CPU:**
```bash
ps aux --sort=-%cpu | head -5
```
Note the PID of the top consumer. If the `TIME` column shows rapid growth between two runs of this command, the process is actively spinning.

**Step 3 — Check kernel messages for OOM killer activity:**
```bash
dmesg | tail -20
```
Look for lines containing `oom-kill` or `Out of memory: Kill process`. If the OOM killer has fired, the situation is already compounding — memory and CPU are both in crisis.

## How to Resolve

1. **Kill the top CPU consumer immediately** if it is not a critical service:
   ```bash
   sudo kill -9 <PID>
   ```
2. If the process is a critical observability service, restart it instead:
   ```bash
   sudo systemctl restart <service-name>
   ```
3. If CPU does not drop after killing the process, check for related child processes:
   ```bash
   sudo pkill -9 -f <process-name>
   ```
4. If the situation is unkillable (processes respawning faster than you can kill them), reboot:
   ```bash
   sudo reboot
   ```
   All observability stack services are configured with `Restart=on-failure` and will restart automatically.

## When to Roll Back and How

If a recent deployment correlates with the CPU spike (check `journalctl -u demo-service --since "15 minutes ago"`):

```bash
sudo systemctl stop demo-service
# Trigger a re-deploy of the previous stable commit via GitHub Actions
sudo systemctl start demo-service
```

For any other observability service that is the offender:
```bash
sudo systemctl restart <prometheus|loki|tempo|grafana-server|otel-collector>
```

## When and To Whom to Escalate

- **Escalate immediately** if CPU is above 90% and you cannot identify the cause within **5 minutes**.
- **Escalate immediately** if the OOM killer has fired.
- **Escalate immediately** if a `sudo kill -9` does not reduce CPU within 60 seconds.
- **Do not wait** for a second opinion — page the on-call engineer now.
- **Contact:** on-call engineer via `#DevOps-Alerts` Slack + direct message. If unreachable, contact the infrastructure team lead.
