# Runbook: HighErrorRate

## What is this alert?
`HighErrorRate` fires when demo-service 5xx ratio exceeds 1% for 2 minutes.

## Likely causes
- Application regression after deployment
- Downstream dependency failure
- Timeout or resource starvation leading to 5xx responses

## First 3 investigation steps
1. Check error-rate and request-rate panels in Grafana Unified Observability dashboard.
2. Query Loki logs for 5xx responses and exception stack traces in the same period.
3. Open associated Tempo traces to find failing span/service.

## Resolution steps
- Roll back the latest deployment if regression is confirmed.
- Restore failing dependency and verify health checks.
- Apply config or timeout fix, then monitor error-rate normalization.

## Rollback guidance
Rollback immediately if 5xx surge follows a deployment and user impact is active.

## Escalation
Escalate to service owner and platform lead if error rate stays above threshold after rollback or first fix attempt.
