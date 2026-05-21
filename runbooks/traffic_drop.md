# Runbook: TrafficDrop

## What is this alert?
`TrafficDrop` fires when demo-service request rate is zero for 5 minutes.

## Likely causes
- Upstream routing/load balancer misconfiguration
- DNS resolution failure
- Ingress or service endpoint outage

## First 3 investigation steps
1. Verify Blackbox probe status and endpoint reachability.
2. Check ingress/load balancer and DNS records for recent changes.
3. Review service logs for startup failures or binding errors.

## Resolution steps
- Restore routing or DNS configuration.
- Restart affected ingress/service components.
- Validate request flow with synthetic probes and live traffic checks.

## Rollback guidance
Rollback network or deployment changes when traffic drop started right after a release/config change.

## Escalation
Escalate to network/platform owner if traffic does not recover within 10 minutes.
