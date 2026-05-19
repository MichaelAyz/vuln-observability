# Alert: DiskWarning

## What Is This Alert?

This alert fires when disk utilisation on the root filesystem exceeds **75% for 5 consecutive minutes**. This is measured as `(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) > 0.75` on the root mount point. The `for: 5m` duration rules out brief spikes from large temporary writes. Disk at 75% is not yet an emergency, but at the current growth trajectory of a full LGTM stack — Prometheus TSDB, Loki chunks, application logs, and binary installations — it could reach critical (90%) within hours or days depending on ingestion rate. This alert provides the window to act before services start crashing.

## Likely Causes

1. **Prometheus TSDB growing beyond its configured retention** — if `--storage.tsdb.retention.time=15d` is not being enforced, old blocks accumulate under `/var/lib/prometheus/`.
2. **Loki chunk and index files accumulating** — Loki stores compressed log chunks under `/var/lib/loki/`; without retention enforced, these grow continuously.
3. **Large log files in `/var/log/`** — systemd journal, nginx, or application logs not being rotated.
4. **Demo service or OTel Collector logs** — high-verbosity logging under load generating GBs of journal entries.
5. **Old binary downloads in `/tmp` or `/home/ubuntu/`** — leftover `.tar.gz` archives from installing exporters or other tools.

## First 3 Investigation Steps

**Step 1 — Check disk usage by filesystem:**
```bash
df -h
```
Confirm which filesystem is over 75%. On this server the relevant filesystem is typically `/` (root). Note the current `Use%` and `Avail` columns.

**Step 2 — Find the largest disk consumers:**
```bash
du -sh /var/lib/prometheus /var/lib/loki /var/lib/grafana /var/log /tmp /home/ubuntu 2>/dev/null | sort -rh | head -20
```
This tells you exactly which directory is consuming the most space. Focus your cleanup on the largest entry first.

**Step 3 — Find unexpectedly large individual files:**
```bash
find /tmp -size +100M 2>/dev/null
find /home/ubuntu -size +100M 2>/dev/null
```
Look for old binary archives (`.tar.gz`, `.zip`) or large log dumps left from troubleshooting sessions.

## How to Resolve

1. **Clean up `/tmp`:**
   ```bash
   sudo rm -rf /tmp/*.tar.gz /tmp/*.zip /tmp/*.deb 2>/dev/null
   ```
2. **Verify and enforce Prometheus retention** — check the running flags:
   ```bash
   sudo systemctl cat prometheus | grep retention
   ```
   If retention is not set, add `--storage.tsdb.retention.time=15d` to the service unit and restart.
3. **Check Loki retention configuration:**
   ```bash
   grep -i retention /etc/loki/loki.yml
   ```
   Ensure `retention_period: 168h` (7 days) is set.
4. **Rotate or truncate large log files:**
   ```bash
   sudo journalctl --vacuum-time=7d
   sudo journalctl --vacuum-size=500M
   ```

## When to Roll Back and How

Not applicable. Disk cleanup does not involve a rollback. Deleting files is irreversible — verify the files are safe to delete before removing anything from `/var/lib/prometheus` or `/var/lib/loki`.

## When and To Whom to Escalate

- If disk is above 75% **and growing faster than 1% per hour** (check with `watch -n 60 df -h`), escalate before it reaches 90%.
- If you cannot identify what is consuming the disk, escalate.
- If DiskCritical fires while this alert is active, treat it as a P1 incident immediately.
- **Contact:** infrastructure team via `#DevOps-Alerts`.
