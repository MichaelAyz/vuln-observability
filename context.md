
## Master Context Document
*Give this to your agent before anything else. This is the single source of truth.*

---

**Project:** `vuln-observability` — Production-Grade Observability Platform

**What we're building:** A fully self-contained observability stack using the LGTM components (Loki, Grafana, Tempo, Prometheus) plus supporting services, wired together with Terraform IaC, SLO/error budget frameworks, DORA metrics, 5 provisioned Grafana dashboards, full alerting with Slack delivery, runbooks, chaos engineering scenarios, and a demo service instrumented with OpenTelemetry. The entire stack must be reproducible with one command.

---

**Infrastructure:**
- VM IP: `13.51.156.192` (AWS, already provisioned)
- Docker and Docker Compose are already installed on the VM
- Terraform will manage the stack (Docker provider for now, AWS provider scaffolded for later)
- All services run as Docker Compose containers with `restart: unless-stopped`

**Services in the stack:**

| Service | Role | Image |
|---|---|---|
| Prometheus | Metrics collection and storage | `prom/prometheus:v2.51.0` |
| Loki | Log aggregation | `grafana/loki:2.9.5` |
| Tempo | Distributed tracing backend | `grafana/tempo:2.4.1` |
| Grafana | Unified observability frontend | `grafana/grafana:10.4.2` |
| Node Exporter | System metrics (CPU, RAM, Disk, Network) | `prom/node-exporter:v1.7.0` |
| Blackbox Exporter | HTTP/SSL probing | `prom/blackbox-exporter:v0.24.0` |
| Alertmanager | Alert routing and Slack delivery | `prom/alertmanager:v0.27.0` |
| OTel Collector | Receives traces and logs, forwards to Tempo and Loki | `otel/opentelemetry-collector-contrib:0.99.0` |
| GitHub Actions Exporter | DORA metrics from GitHub Actions | `cpanato/github-actions-exporter:v1.5.0` |
| Demo Service | Lightweight Python Flask app, OTel instrumented | Custom build |

**Key values:**
- VM IP: `13.51.156.192`
- GitHub repo: `hngprojects/vulnwatch-ui`
- Prod URL: `https://vuln-watch.hng14.com`
- Staging URL: `https://staging.vuln-watch.hng14.com`
- Slack webhook: placeholder for now (`PLACEHOLDER`), wired in Phase 7
- GitHub PAT: placeholder for now, wired in Phase 9
- Metrics retention: 15 days
- Log retention: 7 days

---

**Repository structure** (already scaffolded):

```
vuln-observability/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── docker-compose.yml
├── prometheus/
│   ├── prometheus.yml
│   ├── blackbox.yml
│   └── rules/
│       ├── infrastructure.yml
│       ├── slo_burn_rate.yml
│       └── cicd.yml
├── loki/
│   └── loki-config.yml
├── tempo/
│   └── tempo-config.yml
├── alertmanager/
│   ├── alertmanager.yml
│   └── templates/
│       └── slack.tmpl
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml
│   │   └── dashboards/
│   │       └── dashboards.yml
│   └── dashboards/
│       ├── node_exporter.json
│       ├── blackbox_exporter.json
│       ├── dora_metrics.json
│       ├── slo_error_budget.json
│       └── unified_observability.json
├── otel-collector/
│   └── otel-collector-config.yml
├── demo-service/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── github-actions-exporter/
│   └── config.yml
├── sli-slo/
│   ├── golden_signals.md
│   ├── slo_definitions.md
│   └── error_budget_policy.md
├── runbooks/
│   ├── cpu_warning.md
│   ├── cpu_critical.md
│   ├── memory_warning.md
│   ├── memory_critical.md
│   ├── disk_warning.md
│   ├── disk_critical.md
│   ├── server_down.md
│   ├── slo_fast_burn.md
│   ├── slo_slow_burn.md
│   ├── cfr_threshold_exceeded.md
│   └── mttr_exceeded.md
├── incidents/
│   └── pir_001.md
└── README.md
```

---

**Execution rules your agent must follow:**
- One phase at a time. No phase begins until the previous is verified and approved
- No placeholder logic — if a value is unknown, use an environment variable with a documented default, never a hardcoded fake value that will silently fail
- Every config file must be valid and parseable on first write — no syntax errors
- Alert rules use `vector(0)` placeholders in Phase 1 so `promtool` passes from day one
- Terraform is scaffolded in Phase 1 and grown with each phase — never bolted on at the end
- The demo service skeleton exists from Phase 1 so the OTel pipeline can be verified in Phase 2 before any dashboard is built

---

**Phase execution order and rationale:**

| Phase | What | Why This Order |
|---|---|---|
| 1 | Scaffold + all 8 services running + Terraform foundation + demo service skeleton | Everything else depends on the stack being up |
| 2 | Demo service OTel instrumentation + trace/log pipeline | Unified dashboard (Phase 8) requires live traces — build the source before the display |
| 3 | Prometheus scrape config + all targets wired | Data must flow before SLIs are written |
| 4 | Four Golden Signals SLI definitions | SLIs defined before SLOs |
| 5 | SLO targets, error budgets, policy documents | SLOs defined before alert thresholds |
| 6 | All Prometheus alert rules (promtool validated) | Rules before routing |
| 7 | Alertmanager routing, inhibition, Slack templates | Routing after rules exist |
| 8 | Five Grafana dashboards (all provisioned as JSON) | Dashboards after data + alerts exist |
| 9 | DORA metrics pipeline + recording rules | Depends on GitHub Actions Exporter being up since Phase 1 |
| 10 | Runbooks + blameless PIR | Every alert rule must have a runbook URL that resolves |
| 11 | Game Day — chaos and failure simulation | Proves everything works under real conditions |
| 12 | Terraform hardening + one-command deployment | Finalise IaC after stack is proven stable |

---

## How We'll Work From Here

I will give you one prompt per phase. Each prompt contains:
- Exact files to create or modify
- Exact values to use (no guessing)
- Acceptance criteria your agent must meet before we call the phase done
- What you run to verify it

