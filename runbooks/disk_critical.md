# Alert: DiskCritical

## What Is This Alert?

This alert fires when disk utilisation exceeds **90% for 5 consecutive minutes**. At 90% disk usage, the system is in imminent danger. When a filesystem reaches 100%, all writes fail — this means Prometheus cannot write new TSDB blocks (losing metrics data), Loki cannot write log chunks (losing logs), and systemd cannot write journal entries (losing diagnostics). SQLite databases used by Grafana and Alertmanager will become corrupt. **Services will begin crashing in an unpredictable order. This is a P1 incident. Free disk space immediately — investigation comes after.**

## Likely Causes

1. **Same causes as DiskWarning** — the DiskWarning alert was either not fired, not acted on, or the disk filled faster than expected.
2. **Retention policies not working** — Prometheus or Loki retention not actually enforcing limits, causing unbounded growth.
3. **Runaway log file** — a service entering an error loop and writing GBs of logs per hour (e.g., OTel Collector failing to connect to Tempo/Loki and logging each retry).
4. **A large one-off write** — a database dump, a debug trace capture, or a large binary download that was not cleaned up.
5. **Prometheus TSDB WAL (Write Ahead Log) corruption** — in rare cases, Prometheus can create oversized WAL segments that grow without bound until the service is restarted.

## First 3 Investigation Steps

**Step 1 — Check current disk state:**
```bash
df -h
```
Confirm which filesystem is over 90%. Note the exact `Avail` figure — if under 500MB, act immediately without further investigation.

**Step 2 — Find the largest directories:**
```bash
du -sh /var/lib/* | sort -rh | head -10
```
This gives you the top consumers under `/var/lib`, where Prometheus, Loki, and Grafana store their data. The largest entry is your cleanup target.

**Step 3 — Find very large individual files across the entire system:**
```bash
find / -size +500M -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null
```
Look for unexpected large files — archives, coredumps (`core.*`), or oversized log files.

## How to Resolve

**Act immediately — free space before diagnosing cause:**

1. **Delete known-safe temporary files first:**
   ```bash
   sudo rm -rf /tmp/*.tar.gz /tmp/*.zip /tmp/*.deb /tmp/*.tar 2>/dev/null
   find /tmp -type f -mtime +1 -delete 2>/dev/null
   ```
2. **Vacuum the systemd journal aggressively:**
   ```bash
   sudo journalctl --vacuum-size=100M
   sudo journalctl --vacuum-time=2d
   ```
3. **Truncate large log files** (do NOT delete them, services hold file handles):
   ```bash
   sudo truncate -s 0 /var/log/syslog
   sudo truncate -s 0 /var/log/grafana/grafana.log
   ```
4. **Force Prometheus to compact old blocks** by restarting it (this also drops the WAL):
   ```bash
   sudo systemctl restart prometheus
   ```
5. Verify disk has dropped below 85%:
   ```bash
   df -h
   ```

## When to Roll Back and How

Not applicable directly. However, if disk hits 100%, services will have crashed and must be recovered:

```bash
# Check which services failed
sudo systemctl --failed

# Reset and restart each failed service
sudo systemctl reset-failed <service-name>
sudo systemctl start <service-name>
```

If Grafana's SQLite database is corrupt after a full-disk event:
```bash
sudo systemctl stop grafana-server
sudo rm -f /var/lib/grafana/grafana.db
sudo systemctl start grafana-server
# Grafana will re-provision all dashboards and datasources from disk
```

## When and To Whom to Escalate

- **This is already a P1 incident. Page the on-call engineer now.**
- Do not wait for disk to reach 100% — escalate at the moment this alert fires.
- If disk cannot be freed below 85% within 10 minutes, escalate to the infrastructure team lead.
- If services have crashed due to full disk, escalate and document the recovery steps taken.
- **Contact:** on-call engineer via `#DevOps-Alerts` + direct message. Infrastructure team lead if the on-call engineer is unreachable.
