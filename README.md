# vuln-observability

Production-grade observability and reliability platform — LGTM Stack, DORA Metrics & SLOs.

> README fully populated in Phase 12.

## Quick Start

```bash
# One-command deployment (populated in Phase 12)
terraform init && terraform apply
```

## Stack Components

| Component | Role | Port |
|-----------|------|------|
| Prometheus | Metrics collection & storage | 9090 |
| Loki | Log aggregation | 3100 |
| Tempo | Distributed tracing | 3200 |
| Grafana | Unified observability UI | 3000 |
| Node Exporter | System metrics | 9100 |
| Blackbox Exporter | HTTP/SSL probing | 9115 |
| Alertmanager | Alert routing & Slack delivery | 9093 |
| OTel Collector | Traces + logs pipeline | 4317/4318 |
| Demo Service | OTel-instrumented Flask app | 5000 |
| GitHub Actions Exporter | DORA metrics source | 9999 |

## Dashboard Guide

> Populated in Phase 12.

## Error Budget Policy

> Populated in Phase 4.

## Toil Reduction

> Populated in Phase 8.
