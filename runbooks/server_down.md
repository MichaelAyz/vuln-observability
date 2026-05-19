# Alert: ServerDown

## What Is This Alert?

This alert fires when the Blackbox Exporter HTTP probe against `https://vuln-watch.hng14.com` or `https://staging.vuln-watch.hng14.com` returns `probe_success = 0` for **1 consecutive minute**. The Blackbox Exporter makes a real HTTP GET request from the monitoring server to the application URL every 60 seconds. A failure means end users cannot reach the application — they will see a connection error, SSL error, or timeout. **This alert directly represents user impact. Treat it as a P1 incident until proven otherwise.**

## Likely Causes

1. **Application server is down** — the application process has crashed, or the EC2 instance hosting the application is unreachable.
2. **SSL certificate expired** — HTTPS handshake fails because the certificate is no longer valid. Users see `NET::ERR_CERT_DATE_INVALID`.
3. **DNS resolution failure** — `vuln-watch.hng14.com` is no longer resolving to the correct IP address, possibly due to a misconfigured DNS record or TTL issue.
4. **Firewall rule change** — a security group or iptables rule was changed that blocks inbound HTTP/HTTPS traffic.
5. **Network path disruption** — a routing issue between the monitoring server and the application server, or a CDN/proxy upstream of the application is failing.
6. **Application deployed but not responding** — a recent deployment left the application process not listening on the expected port.

## First 3 Investigation Steps

**Step 1 — Test connectivity to production from the monitoring server:**
```bash
curl -v https://vuln-watch.hng14.com
```
Read the full output carefully:
- `SSL certificate problem: certificate has expired` → SSL certificate is the cause. Follow the SSL path.
- `Could not resolve host` → DNS failure. Check DNS provider.
- `Connection refused` → Application is not listening. Check the application process.
- `Connection timed out` → Network or firewall issue.

**Step 2 — Test connectivity to staging:**
```bash
curl -v https://staging.vuln-watch.hng14.com
```
If production is down but staging is up, the issue is isolated to the production environment. If both are down, the issue is at the DNS or infrastructure level.

**Step 3 — Verify DNS resolution:**
```bash
dig vuln-watch.hng14.com
dig staging.vuln-watch.hng14.com
```
The `ANSWER SECTION` should return a valid IP address. If there is no answer, DNS is broken. If the IP has changed unexpectedly, a DNS record was modified.

## How to Resolve

- **SSL certificate expired:** Contact the application team immediately. They own certificate renewal. The monitoring stack cannot fix this.
- **DNS failure:** Contact the DNS provider or the application team who manages the DNS zone. Check if any DNS changes were made recently.
- **Application process not running:** Contact the application team. They need to restart the application on the server.
- **Firewall rule change:** If you have access to the AWS security groups, check for recent rule changes and revert the blocking rule.
- **Connection refused on a known port:** Verify the application is running on the expected port and that the reverse proxy (nginx) is correctly configured.

## When to Roll Back and How

Not applicable to the monitoring stack. The monitoring stack correctly detected the outage — it is the application that needs to be restored.

If a recent application deployment caused the outage (correlate with the DORA dashboard or GitHub Actions), the application team should roll back via their deployment pipeline. This runbook does not cover the application rollback procedure.

## When and To Whom to Escalate

- **Escalate immediately.** `ServerDown` means users cannot reach the application.
- Do **not** spend more than 3 minutes on investigation before paging the application team.
- Page the on-call engineer **and** the application team lead simultaneously.
- If DNS is the cause, also contact whoever manages the DNS zone.
- **Contact:**
  - On-call engineer: `#DevOps-Alerts` Slack + direct page
  - Application team: `#dev-team` Slack channel
  - DNS issues: DNS provider support or infrastructure team lead
  - If no response within 5 minutes: escalate to engineering manager
