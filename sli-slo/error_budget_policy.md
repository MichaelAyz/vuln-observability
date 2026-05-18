# Error Budget Policy — Vuln Watch Observability Stack

This document defines exactly what the team must do when error budgets are consumed. It exists to make the response to reliability degradation automatic and non-negotiable. By defining these actions upfront, we remove the need for debate every time an incident occurs and ensure we prioritize reliability over feature delivery when it matters most.

---

## Section 1: Budget Consumption Thresholds and Actions

**At 0–50% consumed — Normal operations:**
- All feature work proceeds as normal.
- Reliability improvements are tracked in the backlog but not prioritised over features.
- Weekly SLO review during team standup.

**At 50% consumed — Slowdown:**
- Non-critical feature work is deprioritised.
- At least one reliability improvement must be included in the next sprint.
- The on-call engineer files a brief incident note explaining the cause of consumption.
- SLO review frequency increases to daily.

**At 100% consumed — Feature freeze:**
- All non-critical feature development stops immediately.
- The team enters a reliability sprint.
- No new features ship until the error budget is restored to at least 50%.
- A blameless post-incident review is mandatory within 48 hours.
- The SLO target itself is reviewed—if the budget is consumed every month, the target may be unrealistic or incorrectly defined.

---

## Section 2: Who Owns the Decision

- **Error budget tracking:** The on-call engineer monitors burn rate daily.
- **50% threshold call:** The on-call engineer makes the call and notifies the team lead.
- **100% threshold call:** The team lead enforces the feature freeze. There are no exceptions without explicit sign-off from the engineering manager.
- **SLO target revision:** The engineering manager makes the final decision, which is reviewed quarterly.

---

## Section 3: Burn Rate Alerting

Instead of simple static thresholds, we use multi-window burn rate alerting. A brief spike that resolves quickly should not wake anyone up, but a sustained, moderate burn that accumulates silently is dangerous and requires attention. 

The two burn rate alert thresholds configured for our stack are:

**Fast Burn (Critical):**
- **Condition:** 14.4x burn rate over 1 hour
- **What this means:** 2% of the entire monthly error budget is being consumed every hour. At this rate, the entire budget will be gone in 50 hours.
- **Required action:** Immediate response. Wake the on-call engineer. Treat this as a P1 incident.

**Slow Burn (Warning):**
- **Condition:** 5x burn rate over 6 hours
- **What this means:** 5% of the monthly error budget is consumed in 6 hours. While not immediately critical, it will exhaust the budget in approximately 5 days if left unaddressed.
- **Required action:** Investigate within the business day. Do not wait for the next standup.

---

## Section 4: SLO Review Cadence

- **Daily:** On-call engineer checks the burn rate dashboard.
- **Weekly:** Team reviews SLO compliance in standup—are we on track for the month?
- **Monthly:** Full SLO review. Did we meet our targets? What consumed the budget? Are the targets still appropriate?
- **Quarterly:** SLO targets themselves are rigorously reviewed and revised if necessary based on the previous 3 months of data.

---

## Section 5: What This Policy Does Not Cover

- **Service Scope:** This policy exclusively covers the services monitored by this specific observability stack.
- **Upstream Dependencies:** It does not cover failures caused by upstream dependencies outside our direct control.
- **Infrastructure Saturation:** Infrastructure SLOs (CPU, memory, disk) follow the direct threshold policy outlined in `slo_definitions.md`, not this error budget policy.
- **Planned Maintenance:** Incidents or downtime caused by planned maintenance are explicitly excluded from error budget calculations, provided they are announced at least 48 hours in advance.
