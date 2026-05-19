# Alert: MTTRExceeded

## What Is This Alert?

This alert fires when the **Mean Time to Restore (MTTR)** — calculated as the average duration of successful workflow runs for `hngprojects/vulnwatch-ui` — exceeds **1 hour for 5 consecutive minutes**. In the context of this DORA metrics pipeline, MTTR is proxied by the average time it takes a workflow run to complete successfully after a failure has been detected and a fix has been deployed. An MTTR above 1 hour signals that the team's ability to restore service after a deployment failure is below the DORA High-performance benchmark. This alert is a lagging indicator — it reflects a trend in pipeline velocity and incident response speed, not a real-time outage.

**Important caveat:** Because MTTR is proxied via workflow run duration rather than a direct "time from alert to resolution" measurement, this alert fires when workflows are taking too long to succeed, which can mean slow CI pipelines, complex rollback procedures, or multiple re-run attempts after failures.

## Likely Causes

1. **Manual steps required in the restore process that should be automated** — engineers are performing manual verification, waiting for approvals, or running commands by hand that could be scripted.
2. **Slow CI pipeline** — build, test, and deploy steps taking 30–60 minutes each, meaning even a 1-step fix requires a full pipeline run to confirm.
3. **Unclear ownership of incident response** — no defined on-call rotation or unclear escalation path means time is lost deciding who is responsible for the fix.
4. **Multiple re-run attempts after failures** — a fix attempt fails, then a second attempt is made, then a third — each run contributes to the average duration, increasing MTTR.
5. **Lack of runbooks causing investigation delays** — engineers spend time diagnosing the root cause of a failed deployment without a reference document, adding time before the fix is even written.

## First 3 Investigation Steps

**Step 1 — Check the DORA dashboard MTTR panel for the trend:**

Open the Grafana DORA Metrics dashboard. Examine the `MTTR (Mean Time to Restore)` panel. Look at the trend: is MTTR increasing week-over-week, or was there a single spike that brought the average up? A single slow incident (e.g., a complex rollback) can inflate the metric temporarily. A consistent upward trend indicates a systemic process problem.

**Step 2 — Query the average workflow run duration from Prometheus:**
```bash
curl -s http://localhost:9090/api/v1/query \
  --data-urlencode 'query=avg(github_workflow_run_duration_ms{repo="hngprojects/vulnwatch-ui"} * on(id) (github_workflow_run_status == 1)) / 1000' \
  | python3 -m json.tool
```
The result is the average duration in seconds of successful workflow runs. A value above 3600 (3600 seconds = 1 hour) confirms the alert threshold has been breached.

**Step 3 — Review recent workflow run durations on GitHub:**

Open `https://github.com/hngprojects/vulnwatch-ui/actions` and look at the duration column for recent runs. Identify which specific runs took the longest. Click into the run logs and identify which step within the workflow is consuming the most time.

## How to Resolve

1. **If the slow workflows are caused by a single long-running step:**
   - Open a PR to optimise that step — parallelise test suites, cache dependencies, or use incremental builds.
   - If the step is a deployment step waiting for a health check, reduce the health check interval or implement a faster readiness probe.

2. **If MTTR is elevated due to multiple failed re-runs before a success:**
   - Investigate why the initial fix attempts failed. Are tests non-deterministic? Are there race conditions in the deployment?
   - Add better pre-deployment validation to catch issues earlier, before they reach the deployment step.

3. **If the root cause is slow manual incident response:**
   - Review the on-call rotation and ensure runbooks are up to date and accessible.
   - Conduct a blameless retrospective on the slowest incidents to identify the bottlenecks.
   - Define a maximum time-to-acknowledge for alerts (e.g., 5 minutes) and a time-to-action target (e.g., 15 minutes).

4. **If pipeline infrastructure is the bottleneck** (GitHub Actions runner provisioning time, slow runner hardware):
   - Consider self-hosted runners for faster job startup.
   - Optimise Docker layer caching to reduce build times.

## When to Roll Back and How

MTTR is a lagging indicator — it reflects past performance, not a current active incident. Rolling back is not applicable to address this specific alert.

However, if the high MTTR is caused by a pattern of failed deployments that each required rollbacks, the application team should review their deployment strategy and consider:
- Blue/green deployments to enable instant rollback
- Feature flags to decouple deployment from feature release
- More rigorous staging validation before production deploys

## When and To Whom to Escalate

- If the MTTR trend is **increasing over 2 or more consecutive weeks**, escalate to the engineering manager for a process review.
- If MTTR exceeds **4 hours** on average (indicating major systemic issues with incident response), escalate immediately.
- A rising MTTR combined with a rising CFR is a signal that the team is in a reliability debt spiral — escalate to the engineering manager and consider triggering an Error Budget Policy reliability sprint.
- **Contact:**
  - Engineering manager: if MTTR is trending upward over multiple weeks
  - Application team lead: to discuss pipeline optimisation and incident response improvements
  - `#dev-team` Slack: to share MTTR trend data and initiate a retrospective
