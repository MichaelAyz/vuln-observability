# Alert: MemoryWarning

## What Is This Alert?

This alert fires when memory utilisation on the production server exceeds **80% for 5 consecutive minutes**. This is calculated as `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.80`. The `for: 5m` duration ensures the alert is not triggered by brief allocations during garbage collection. At 80% memory usage, the system is approaching the point where the Linux kernel may begin using swap, which causes significant performance degradation. This alert is a warning — it requires investigation but is not yet an emergency.

## Likely Causes

1. **Memory leak in a long-running service** — Prometheus, Loki, or the demo service allocating memory over time without releasing it. Common in Python services (demo service) and in Prometheus TSDB under high cardinality.
2. **Loki or Prometheus consuming more memory than expected** — during high ingestion periods, both services buffer chunks and TSDB blocks in memory before flushing to disk.
3. **Large log ingestion spike** — the OTel Collector receiving a burst of logs from the demo service, buffering them in the pipeline before forwarding to Loki.
4. **Insufficient server RAM for the full LGTM stack** — the combined memory footprint of Prometheus, Loki, Tempo, Grafana, Alertmanager, OTel Collector, and Node Exporter may exceed available RAM under concurrent load.
5. **Unused memory fragmentation** — not a leak, but the kernel holding memory in slab caches that could be reclaimed if needed.

## First 3 Investigation Steps

**Step 1 — Get the full memory breakdown:**
```bash
free -h
```
Look at the `available` column, not `free`. Available memory accounts for cache that can be reclaimed. If available is under 200MB, the situation is approaching critical.

**Step 2 — Identify the top memory consumers:**
```bash
ps aux --sort=-%mem | head -10
```
Look at the `%MEM` and `RSS` columns. Identify which service is using the most resident memory. Cross-reference with known baselines: Prometheus typically uses 200–400MB, Loki 150–300MB, Grafana 100–200MB on a lightly loaded system.

**Step 3 — Get detailed kernel memory state:**
```bash
cat /proc/meminfo | grep -E "MemTotal|MemAvailable|SwapTotal|SwapUsed|Cached|Buffers"
```
If `SwapUsed` is non-zero, the kernel is already paging — this is more urgent than it appears. If `Cached` is large, memory is recoverable and the situation is less critical.

## How to Resolve

1. If Prometheus is the top consumer, check its memory usage and consider lowering retention:
   ```bash
   sudo systemctl status prometheus
   curl -s http://localhost:9090/api/v1/status/runtimeinfo | python3 -m json.tool | grep -E "storageRetention|goroutines"
   ```
2. If Loki is the top consumer, restart it (Loki does not have persistent in-memory state that would be lost):
   ```bash
   sudo systemctl restart loki
   ```
3. If the demo service is leaking memory, restart it:
   ```bash
   sudo systemctl restart demo-service
   ```
4. If swap is not in use and available memory is above 300MB, monitor for 10 more minutes — the spike may self-resolve.

## When to Roll Back and How

If a recent deployment of the demo service correlates with the memory growth:
```bash
sudo systemctl stop demo-service
# Trigger rollback deployment via GitHub Actions
sudo systemctl start demo-service
```

If Prometheus or Loki are the offenders, a restart is the equivalent of a rollback:
```bash
sudo systemctl restart prometheus
sudo systemctl restart loki
```

## When and To Whom to Escalate

- Escalate immediately if `SwapUsed` is non-zero **and** growing — OOM kill is imminent.
- Escalate if memory stays above 80% for more than **20 minutes** after attempting restarts.
- Escalate if `MemoryCritical` fires while this alert is active.
- **Contact:** infrastructure team via `#DevOps-Alerts`. If swap is being used, page the on-call engineer directly — do not wait.
