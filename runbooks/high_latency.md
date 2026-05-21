# Runbook: HighLatency

## What is this alert?
`HighLatency` fires when demo-service p95 request latency is above 500ms for 2 minutes.

## Likely causes
- Upstream dependency slowdown
- CPU or memory pressure on host
- Elevated request burst/traffic spike

## First 3 investigation steps
1. Check Grafana Unified Observability dashboard latency and error panels for the same time window.
2. Inspect correlated Loki logs for slow endpoints and error patterns.
3. Open related traces in Tempo and identify the longest span/service hop.

## Resolution steps
- Scale down traffic source or stabilize noisy client if traffic spike caused saturation.
- Restart or roll back the affected service if a recent deploy introduced regression.
- Fix slow downstream calls and retry with timeout/circuit-breaker controls where needed.

## Rollback guidance
Rollback when latency increase started immediately after deployment and persists after quick mitigation.

## Escalation
Escalate to platform/on-call lead if latency remains above SLO for 15 minutes after first response.
