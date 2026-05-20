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
    install_hash           = filemd5("${path.root}/../systemd/install.sh")
    github_repository_hash = var.github_repository
    github_pat_hash        = var.github_pat
    slack_webhook_url_hash = var.slack_webhook_url
  }

  # ── Step 1: Package and copy the repo to the VM ──────────────────────────────
  provisioner "local-exec" {
    command     = <<EOT
      Set-Location -Path "${abspath(path.root)}/../"
      tar -czf deploy.tar.gz --exclude=.git --exclude=terraform/.terraform --exclude=terraform/*.tfstate* --exclude=deploy.tar.gz .
      scp -i "${abspath(path.root)}/${var.ssh_private_key_path}" -o StrictHostKeyChecking=no deploy.tar.gz "${var.vm_user}@${var.vm_host}:/home/${var.vm_user}/deploy.tar.gz"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  # ── Step 2: Extract files and run the install script ─────────────────────────
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
      "rm -f /home/${var.vm_user}/deploy.tar.gz",
      "cd /home/${var.vm_user}/vuln-observability",
      "chmod +x systemd/install.sh",
      "sudo SLACK_WEBHOOK_URL='${var.slack_webhook_url}' GITHUB_PAT='${var.github_pat}' GITHUB_REPOSITORY='${var.github_repository}' ./systemd/install.sh"
    ]
  }
}
