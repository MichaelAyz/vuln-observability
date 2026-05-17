variable "vm_host" {
  type        = string
  description = "IP or hostname of the monitoring VM"
  default     = "3.219.30.122"
}

variable "vm_user" {
  type        = string
  description = "SSH user on the monitoring VM"
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to the SSH private key for VM access"
  # No default — this must be supplied explicitly (never commit a key path)
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
  default     = "admin"
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack Incoming Webhook URL for DevOps-Alerts"
  sensitive   = true
  default     = "https://hooks.slack.com/services/PLACEHOLDER"
}

variable "github_pat" {
  type        = string
  description = "GitHub Personal Access Token with repo and workflow scopes"
  sensitive   = true
  default     = "placeholder_token"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository to watch for DORA metrics in org/repo format"
  default     = "hngprojects/vulnwatch-ui"
}

variable "aws_region" {
  type        = string
  description = "AWS region where the monitoring VM lives"
  default     = "eu-west-2"
}
