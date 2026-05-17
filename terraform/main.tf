# ============================================================================
# main.tf — Deploys the vuln-observability stack onto the existing VM via SSH
#
# Approach: remote-exec via null_resource
#   Terraform's built-in file provisioner cannot copy directories recursively,
#   so we use local-exec to rsync the entire repo to the VM first, then
#   remote-exec to pull images and bring the stack up with docker compose.
#
# One-command deployment:
#   terraform init && terraform apply -var="ssh_private_key_path=~/.ssh/your_key"
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # Scaffolded for later use — not yet configured.
      # Uncomment the provider block below and switch backend to S3
      # when AWS credentials are available.
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # Switch to S3 backend when AWS credentials are available:
  # backend "s3" {
  #   bucket = "vuln-observability-tfstate"
  #   key    = "observability/terraform.tfstate"
  #   region = var.aws_region
  # }
  backend "local" {}
}

# AWS provider scaffolded — uncomment when credentials are configured
# provider "aws" {
#   region = var.aws_region
# }

# ── Deploy the full observability stack onto the VM ────────────────────────────
resource "null_resource" "deploy_observability_stack" {

  # Re-run this resource whenever docker-compose.yml changes.
  # Add other critical files here to trigger re-deploys on config changes.
  triggers = {
    compose_hash = filemd5("${path.root}/../docker-compose.yml")
  }

  # ── Step 1: rsync the repo to the VM ────────────────────────────────────────
  # Terraform's file provisioner copies individual files only, not directories.
  # rsync handles the full recursive directory copy efficiently, skipping
  # unchanged files and removing deleted ones (--delete flag).
  provisioner "local-exec" {
    command = <<-EOT
      rsync -avz --delete \
        --exclude='.git' \
        --exclude='*.tfstate' \
        --exclude='*.tfstate.backup' \
        -e "ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        ${path.root}/../ \
        ${var.vm_user}@${var.vm_host}:/home/${var.vm_user}/vuln-observability/
    EOT
  }

  # ── Step 2: Pull images and bring the stack up ───────────────────────────────
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = var.vm_host
      user        = var.vm_user
      private_key = file(var.ssh_private_key_path)
      timeout     = "5m"
    }

    inline = [
      "cd /home/${var.vm_user}/vuln-observability",
      "export SLACK_WEBHOOK_URL='${var.slack_webhook_url}'",
      "export GITHUB_PAT='${var.github_pat}'",
      "docker compose pull",
      "docker compose up -d --remove-orphans",
      "docker compose ps",
    ]
  }
}
