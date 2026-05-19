# Alert: CFRThresholdExceeded

## What Is This Alert?

This alert fires when the **Change Failure Rate (CFR)** for the `hngprojects/vulnwatch-ui` repository exceeds **15% for 5 consecutive minutes**. CFR is the percentage of deployments that resulted in a failure — specifically, GitHub Actions workflow runs that completed with a failing status. The DORA benchmark for an Elite or High-performing team is CFR below 15%. When this alert fires, more than 1 in 7 of all workflow runs tracked by the GitHub Actions Exporter have failed. This is a signal that the CI/CD pipeline quality is below acceptable thresholds and needs engineering attention.

**Important context:** The `for: 5m` in this alert is not about a time-based threshold on the metric — it prevents flapping if the CFR briefly crosses 15% and then drops back. Once the metric confirms CFR > 15% for a sustained period, the alert fires.

## Likely Causes

1. **Insufficient test coverage** — regressions are reaching the CI pipeline because unit or integration tests are not catching them.
2. **Flaky tests** — non-deterministic tests that sometimes pass and sometimes fail, causing a percentage of runs to fail without a code change being the root cause.
3. **Environment-specific issues in production** — the CI environment differs from production in ways that cause code that passes tests to fail on deployment (environment variables, dependencies, database versions).
4. **Rushed deployments without proper review** — PRs merged without adequate review, skipping the defect-catching step.
5. **Infrastructure instability affecting CI runners** — GitHub Actions runners encountering intermittent failures not related to the code (network timeouts, resource exhaustion on runners, Docker Hub rate limiting).

## First 3 Investigation Steps

**Step 1 — Check the DORA dashboard for which workflows are failing most:**

Open the Grafana DORA Metrics dashboard. Examine the `Deployment History` panel to see the ratio of successes (green) to failures (red) over time. Look for when the failure rate increased — this helps narrow down which deployment or change introduced the problem.

**Step 2 — Query Prometheus for the raw failure count:**
```bash
curl -s http://localhost:9090/api/v1/query \
  --data-urlencode 'query=count(github_workflow_run_status{repo="hngprojects/vulnwatch-ui"} == 0)' \
  | python3 -m json.tool
```
The result gives the total number of failed workflow runs tracked. Cross-reference with the total run count to calculate the current CFR manually.

**Step 3 — Review recent failed runs on GitHub directly:**

Open `https://github.com/hngprojects/vulnwatch-ui/actions` in your browser. Filter by "Failing" runs. Read the error output from each failed run. Look for a pattern — the same step failing across multiple runs is a flaky test or infrastructure issue; different steps failing in different runs may indicate environment drift.

## How to Resolve

1. **If the cause is flaky tests:** Open issues in the `vulnwatch-ui` repository to track each flaky test. Add retry logic or quarantine the tests while a fix is developed.
2. **If the cause is regressions:** Identify the PR or commit that introduced the regression. Revert it or fast-fix it. Ensure that the failing test is added to the suite so this specific regression is caught in future.
3. **If the cause is environment drift:** Compare the CI environment configuration with the production environment. Update environment variables, dependency versions, or Docker base images to match.
4. **If the cause is runner infrastructure:** Check the GitHub Actions status page (`https://www.githubstatus.com/`) for platform incidents. If GitHub itself is having issues, wait and monitor.
5. **Enforce a deployment freeze** on new features while CFR is above 15% — only reliability fixes should be merged until CFR drops below the threshold.

## When to Roll Back and How

Each failed deployment may need to be individually rolled back in the application repository. This runbook does not own the application rollback procedure — contact the application team.

For any failed deployment that made it to production before the CI check caught it, the application team should:
1. Identify the last known-good commit.
2. Open a rollback PR targeting that commit.
3. Fast-track the PR through review.
4. Merge and verify the deployment succeeds.

## When and To Whom to Escalate

- If CFR is above 15% for more than **2 consecutive days**, escalate to the engineering manager.
- Per the Error Budget Policy: sustained CFR above 15% triggers a **reliability sprint** — no new features until CFR is back within threshold.
- If the root cause cannot be identified within one business day, escalate to the team lead.
- **Contact:**
  - Engineering manager: if CFR > 15% for 2+ consecutive days
  - Application team lead: for investigation of failing workflows
  - `#dev-team` Slack: to announce the deployment freeze while CFR is elevated
