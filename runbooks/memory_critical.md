# Alert: MemoryCritical

## What Is This Alert?

This alert fires when memory utilisation exceeds **90% for 10 consecutive minutes**. At this level, the Linux OOM (Out Of Memory) killer may have already fired or is imminent. When the OOM killer fires, it terminates processes without warning — it chooses victims based on score, not criticality. This means Prometheus, Loki, or Grafana could be killed unexpectedly, causing data loss and gaps in monitoring. **This is a P1 incident. Do not wait — act immediately.**

## Likely Causes

1. **OOM condition — the OOM killer has already or is about to fire** — memory is exhausted, swap (if present) is also full, and the kernel is in crisis mode.
2. **Memory leak that was not caught at the MemoryWarning threshold** — a service that was consuming memory slowly has now reached critical levels.
3. **Loki or Prometheus under extreme ingestion pressure** — both services buffer heavily in memory before flushing; a log storm or high-cardinality metric explosion can consume gigabytes.
4. **Multiple simultaneous service memory spikes** — no single service is the culprit, but the combined footprint of all services has exceeded capacity.
5. **Same causes as MemoryWarning** — but the window for gentle intervention has passed.

## First 3 Investigation Steps

**Step 1 — Check if OOM killer has already fired:**
```bash
dmesg | grep -i "oom\|killed" | tail -10
```
Look for lines like `Out of memory: Kill process 1234 (prometheus) score 456 or sacrifice child`. If you see this, a service has already been killed. Check which one and restart it immediately.

**Step 2 — Get current memory state:**
```bash
free -h
```
If `available` is under 50MB, OOM kill is seconds away. Proceed directly to resolution — skip further investigation.

**Step 3 — Identify the highest memory consumer:**
```bash
ps aux --sort=-%mem | head -5
```
Get the PID of the top consumer. This is your target for immediate action.

## How to Resolve

1. **Immediately restart the highest memory consumer** — do not investigate further:
   ```bash
   sudo systemctl restart <service-name>
   ```
2. If a service was already killed by the OOM killer, restart it:
   ```bash
   sudo systemctl start <service-name>
   sudo systemctl status <service-name>
   ```
3. If memory is critically low and a restart is too slow, drop the kernel page cache to free memory immediately:
   ```bash
   sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
   ```
   > ⚠️ This drops cached data and may temporarily impact disk I/O performance. It is safe to run but is a temporary measure — the root cause must still be fixed.
4. Verify memory has recovered:
   ```bash
   free -h
   ```

## When to Roll Back and How

If the demo service or any recently deployed service is the top memory consumer:
```bash
sudo systemctl stop demo-service
sudo systemctl start demo-service
```

If the OOM killer killed a service and it is not restarting automatically:
```bash
sudo systemctl reset-failed <service-name>
sudo systemctl start <service-name>
```

## When and To Whom to Escalate

- **Escalate immediately — this is a P1 incident.** Do not spend more than 2 minutes investigating before paging the on-call engineer.
- If the OOM killer has fired, escalate immediately regardless of whether the service restarted successfully.
- If memory does not drop below 85% within 5 minutes of restarting the top consumer, escalate.
- If the system needs a reboot, escalate first and reboot with approval.
- **Contact:** on-call engineer via `#DevOps-Alerts` Slack + direct page. Do not wait for a response before acting — restart the offending service immediately.
