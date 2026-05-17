output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${var.vm_host}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${var.vm_host}:9090"
}

output "alertmanager_url" {
  description = "Alertmanager URL"
  value       = "http://${var.vm_host}:9093"
}

output "loki_url" {
  description = "Loki URL"
  value       = "http://${var.vm_host}:3100"
}

output "tempo_url" {
  description = "Tempo URL"
  value       = "http://${var.vm_host}:3200"
}

output "demo_service_url" {
  description = "Demo service URL"
  value       = "http://${var.vm_host}:8080"
}
