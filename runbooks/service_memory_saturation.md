# Runbook: ServiceMemorySaturation

## What is this alert?
`ServiceMemorySaturation` fires when demo-service resident memory exceeds 85% for 5 minutes.

## Likely causes
- Memory leak in application code
- Unexpected traffic pattern increasing memory footprint
- Host memory contention from co-located services

## First 3 investigation steps
1. Check Node Exporter memory panels and demo-service process memory trend.
2. Inspect recent deploy history for memory-related code changes.
3. Review logs for OOM warnings, restarts, or GC pressure indicators.

## Resolution steps
- Restart service to recover immediate pressure.
- Reduce load and isolate high-memory endpoints.
- Patch and redeploy memory-efficient fix.

## Rollback guidance
Rollback if memory growth pattern starts after a recent release and keeps climbing after restart.

## Escalation
Escalate to app owner and platform lead if memory remains above threshold for 15 minutes or OOM events occur.
