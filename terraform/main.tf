# ============================================================================
# main.tf — Deploys the vuln-observability stack onto the existing VM via SSH
#
# Approach: remote-exec via null_resource
#   Terraform's built-in file provisioner cannot copy directories recursively,
#   so we use local-exec to rsync the entire repo to the VM first, then
#   remote-exec to install and configure the stack using systemd.
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

  # Re-run this resource whenever the install script changes.
  # Add other critical files here to trigger re-deploys on config changes.
  triggers = {
    install_hash = filemd5("${path.root}/../systemd/install.sh")
  }

  # ── Step 1: rsync the repo to the VM ────────────────────────────────────────
  # Terraform's file provisioner copies individual files only, not directories.
  # rsync handles the full recursive directory copy efficiently, skipping
  # unchanged files and removing deleted ones (--delete flag).
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.root}/../ && tar -czf deploy.tar.gz --exclude=.git --exclude=terraform/.terraform --exclude=terraform/*.tfstate* --exclude=deploy.tar.gz .
      scp -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no deploy.tar.gz ${var.vm_user}@${var.vm_host}:/home/${var.vm_user}/deploy.tar.gz
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
      "mkdir -p /home/${var.vm_user}/vuln-observability",
      "tar -xzf /home/${var.vm_user}/deploy.tar.gz -C /home/${var.vm_user}/vuln-observability",
      "cd /home/${var.vm_user}/vuln-observability",
      "chmod +x systemd/install.sh",
      "sudo SLACK_WEBHOOK_URL='${var.slack_webhook_url}' GITHUB_PAT='${var.github_pat}' GITHUB_REPOSITORY='${var.github_repository}' ./systemd/install.sh"
    ]
  }
}
