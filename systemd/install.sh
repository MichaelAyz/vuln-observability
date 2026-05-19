#!/bin/bash
# ============================================================================
# install.sh — Installs, configures, and starts the full vuln-observability
# stack as native systemd services on Ubuntu.
#
# Usage:
#   sudo SLACK_WEBHOOK_URL="https://hooks.slack.com/..." GITHUB_PAT="ghp_..." ./systemd/install.sh
#
# Idempotent: safe to run multiple times on the same server.
# Must be run from the repository root directory.
# ============================================================================
set -euo pipefail

# ============================================================================
# Section 0 — Strict mode and variables
# ============================================================================
PROMETHEUS_VERSION=2.51.0
LOKI_VERSION=2.9.5
TEMPO_VERSION=2.4.1
NODE_EXPORTER_VERSION=1.7.0
BLACKBOX_VERSION=0.24.0
ALERTMANAGER_VERSION=0.27.0
OTEL_VERSION=0.99.0
GH_EXPORTER_VERSION=1.5.0

INSTALL_DIR=/usr/local/bin
CONFIG_BASE=/etc
DATA_BASE=/var/lib
REPO_DIR=$(pwd)

SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-https://hooks.slack.com/services/PLACEHOLDER}
GITHUB_PAT=${GITHUB_PAT:-placeholder_token}

echo "==> Starting vuln-observability installation from: $REPO_DIR"

# ============================================================================
# Section 1 — System preparation
# ============================================================================
echo "==> Preparing system..."
apt-get update -y
apt-get install -y curl wget tar unzip python3 python3-pip python3-venv adduser libfontconfig1 apt-transport-https software-properties-common


# Add Grafana apt repository and install grafana=10.4.2
if ! dpkg -l | grep -q "^ii  grafana "; then
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /usr/share/keyrings/grafana.gpg
  echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
  apt-get update -y
  apt-get install -y grafana=10.4.2
fi

systemctl daemon-reload

# ============================================================================
# Section 2 — Create system users (idempotent)
# ============================================================================
echo "==> Creating system users..."
for user in prometheus loki tempo node_exporter blackbox alertmanager otel ghexporter demoservice; do
  if ! id -u "$user" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /bin/false "$user"
    echo "  Created user: $user"
  fi
done

# ============================================================================
# Section 3 — Create data and config directories
# ============================================================================
echo "==> Creating data and config directories..."
for service in prometheus loki tempo alertmanager; do
  mkdir -p ${CONFIG_BASE}/${service}
  mkdir -p ${DATA_BASE}/${service}
done

# Prometheus rules subdirectory — required for cp -r in Section 5
mkdir -p /etc/prometheus/rules

# Alertmanager templates subdirectory — required for cp -r in Section 5
mkdir -p /etc/alertmanager/templates

# Grafana dashboards subdirectory
mkdir -p /var/lib/grafana/dashboards

mkdir -p ${CONFIG_BASE}/otel-collector
mkdir -p ${CONFIG_BASE}/blackbox-exporter
mkdir -p ${CONFIG_BASE}/github-actions-exporter
mkdir -p /var/log/demo-service
mkdir -p /opt/demo-service

# ============================================================================
# Section 4 — Download and install binaries
# ============================================================================
echo "==> Downloading and installing binaries..."
# Use /var/tmp (disk-backed) instead of /tmp (RAM tmpfs on small instances)
TMP_DIR=$(mktemp -d -p /var/tmp)
cd "$TMP_DIR"

# Prometheus
if [ ! -f "${INSTALL_DIR}/prometheus" ]; then
  echo "  Downloading Prometheus ${PROMETHEUS_VERSION}..."
  wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
  tar xf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
  cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus ${INSTALL_DIR}/
  cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/prometheus ${INSTALL_DIR}/promtool
  rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*
  echo "  [OK] prometheus installed"
fi

# Loki
if [ ! -f "${INSTALL_DIR}/loki" ]; then
  echo "  Downloading Loki ${LOKI_VERSION}..."
  wget -q "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
  unzip -q loki-linux-amd64.zip loki-linux-amd64
  mv loki-linux-amd64 loki
  cp loki ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/loki
  rm -f loki loki-linux-amd64.zip
  echo "  [OK] loki installed"
fi

# Tempo
if [ ! -f "${INSTALL_DIR}/tempo" ]; then
  echo "  Downloading Tempo ${TEMPO_VERSION}..."
  wget -q "https://github.com/grafana/tempo/releases/download/v${TEMPO_VERSION}/tempo_${TEMPO_VERSION}_linux_amd64.tar.gz"
  tar xf tempo_${TEMPO_VERSION}_linux_amd64.tar.gz tempo
  cp tempo ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/tempo
  rm -f tempo tempo_${TEMPO_VERSION}_linux_amd64.tar.gz
  echo "  [OK] tempo installed"
fi

# Node Exporter
if [ ! -f "${INSTALL_DIR}/node_exporter" ]; then
  echo "  Downloading Node Exporter ${NODE_EXPORTER_VERSION}..."
  wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
  tar xf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
  cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/node_exporter
  rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
  echo "  [OK] node_exporter installed"
fi

# Blackbox Exporter
if [ ! -f "${INSTALL_DIR}/blackbox_exporter" ]; then
  echo "  Downloading Blackbox Exporter ${BLACKBOX_VERSION}..."
  wget -q "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz"
  tar xf blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz
  cp blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64/blackbox_exporter ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/blackbox_exporter
  rm -rf blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64*
  echo "  [OK] blackbox_exporter installed"
fi

# Alertmanager
if [ ! -f "${INSTALL_DIR}/alertmanager" ]; then
  echo "  Downloading Alertmanager ${ALERTMANAGER_VERSION}..."
  wget -q "https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz"
  tar xf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
  cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/alertmanager ${INSTALL_DIR}/
  cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/amtool ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/alertmanager ${INSTALL_DIR}/amtool
  rm -rf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64*
  echo "  [OK] alertmanager installed"
fi

# OTel Collector
if [ ! -f "${INSTALL_DIR}/otelcol-contrib" ]; then
  echo "  Downloading OTel Collector ${OTEL_VERSION}..."
  if wget -q "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_amd64.tar.gz"; then
    tar xf otelcol-contrib_${OTEL_VERSION}_linux_amd64.tar.gz otelcol-contrib
    cp otelcol-contrib ${INSTALL_DIR}/
    chmod 755 ${INSTALL_DIR}/otelcol-contrib
    rm -f otelcol-contrib otelcol-contrib_${OTEL_VERSION}_linux_amd64.tar.gz
    echo "  [OK] otelcol-contrib installed"
  else
    echo "  [WARN] Failed to download otelcol-contrib — otel-collector service will not start"
  fi
fi

# GitHub Actions Exporter — non-fatal, download may not exist for all versions
if [ ! -f "${INSTALL_DIR}/github-actions-exporter" ]; then
  echo "  Downloading GitHub Actions Exporter ${GH_EXPORTER_VERSION}..."
  (
    set +e
    GH_URL="https://github.com/cpanato/github-actions-exporter/releases/download/v${GH_EXPORTER_VERSION}"
    wget -q "${GH_URL}/github-actions-exporter_${GH_EXPORTER_VERSION}_Linux_x86_64.tar.gz" \
      || wget -q "${GH_URL}/github-actions-exporter_${GH_EXPORTER_VERSION}_linux_amd64.tar.gz" \
      || true
    ARCHIVE=$(ls github-actions-exporter_*.tar.gz 2>/dev/null | head -1)
    if [ -n "$ARCHIVE" ]; then
      tar xf "$ARCHIVE"
      BIN=$(ls github-actions-exporter github-actions-exporter_linux_amd64 2>/dev/null | head -1)
      if [ -n "$BIN" ]; then
        cp "$BIN" ${INSTALL_DIR}/github-actions-exporter
        chmod 755 ${INSTALL_DIR}/github-actions-exporter
        echo "  [OK] github-actions-exporter installed"
      fi
      rm -f "$ARCHIVE" github-actions-exporter github-actions-exporter_linux_amd64
    else
      echo "  [WARN] github-actions-exporter v${GH_EXPORTER_VERSION} not found — DORA metrics will be unavailable"
    fi
  )
fi

cd "$REPO_DIR"
rm -rf "$TMP_DIR"

# ============================================================================
# Section 5 — Copy config files from repo to system paths
# ============================================================================
echo "==> Copying configuration files..."
cp "${REPO_DIR}/prometheus/prometheus.yml"            /etc/prometheus/prometheus.yml
cp "${REPO_DIR}/prometheus/blackbox.yml"              /etc/blackbox-exporter/config.yml
cp -r "${REPO_DIR}/prometheus/rules/."               /etc/prometheus/rules/
cp "${REPO_DIR}/loki/loki-config.yml"                /etc/loki/loki-config.yml
cp "${REPO_DIR}/tempo/tempo-config.yml"              /etc/tempo/tempo-config.yml
cp "${REPO_DIR}/alertmanager/alertmanager.yml"       /etc/alertmanager/alertmanager.yml
cp -r "${REPO_DIR}/alertmanager/templates/."         /etc/alertmanager/templates/
cp "${REPO_DIR}/otel-collector/otel-collector-config.yml" /etc/otel-collector/config.yml
cp -r "${REPO_DIR}/grafana/provisioning/."           /etc/grafana/provisioning/
cp -r "${REPO_DIR}/grafana/dashboards/"*.json        /var/lib/grafana/dashboards/

echo "==> Setting directory ownership..."
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown -R loki:loki             /etc/loki /var/lib/loki
chown -R tempo:tempo           /etc/tempo /var/lib/tempo
chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
chown -R blackbox:blackbox     /etc/blackbox-exporter
chown -R otel:otel             /etc/otel-collector
chown -R ghexporter:ghexporter /etc/github-actions-exporter
chown -R grafana:grafana       /etc/grafana /var/lib/grafana

# ============================================================================
# Section 6 — Substitute environment variables in configs
# ============================================================================
echo "==> Substituting environment variables..."

# Replace the entire placeholder webhook URL with the real one
sed -i "s|https://hooks.slack.com/services/PLACEHOLDER|${SLACK_WEBHOOK_URL}|g" /etc/alertmanager/alertmanager.yml

# ============================================================================
# Section 7 — Install and configure demo service
# ============================================================================
echo "==> Installing demo service..."
cp "${REPO_DIR}/demo-service/app.py"           /opt/demo-service/
cp "${REPO_DIR}/demo-service/requirements.txt" /opt/demo-service/

# Recreate venv if requirements changed (delete old venv to pick up new protobuf)
if [ ! -d /opt/demo-service/venv ]; then
  python3 -m venv /opt/demo-service/venv
fi
/opt/demo-service/venv/bin/pip install --quiet --upgrade -r /opt/demo-service/requirements.txt

chown -R demoservice:demoservice /opt/demo-service

# ============================================================================
# Section 8 — Install systemd unit files
# ============================================================================
echo "==> Installing systemd unit files..."
cp "${REPO_DIR}/systemd/"*.service /etc/systemd/system/

# Create the github-actions-exporter env file automatically
if [ "${GITHUB_PAT}" != "placeholder_token" ]; then
  echo "GITHUB_TOKEN=${GITHUB_PAT}" > /etc/github-actions-exporter/env
  chmod 600 /etc/github-actions-exporter/env
  chown ghexporter:ghexporter /etc/github-actions-exporter/env
fi

systemctl daemon-reload

# ============================================================================
# Section 9 — Enable and start all services
# ============================================================================
echo "==> Enabling and starting services..."

SERVICES="grafana-server prometheus loki tempo node-exporter blackbox-exporter alertmanager otel-collector github-actions-exporter demo-service"

for srv in $SERVICES; do
  systemctl enable "$srv" || echo "  [WARN] Could not enable $srv"
  systemctl restart "$srv" || echo "  [WARN] Could not start $srv — check: journalctl -u $srv -n 20"
done

echo "==> Note on Grafana Authentication:"
# By design, Grafana uses admin/admin for the initial login. 
# We do not use grafana-cli admin reset-admin-password here because the 
# SQLite DB initialization takes 5-15 seconds after the service starts, 
# and running it immediately will cause set -e to abort the script.

# ============================================================================
# Section 10 — Health verification
# ============================================================================
echo "==> Waiting 10 seconds for services to initialize..."
sleep 10

echo ""
echo "==> Service Health Verification:"
ALL_OK=true
for srv in $SERVICES; do
  STATUS=$(systemctl is-active "$srv" 2>/dev/null || echo "unknown")
  if [ "$STATUS" = "active" ]; then
    echo "  [ OK ] $srv"
  else
    echo "  [FAIL] $srv ($STATUS) — run: journalctl -u $srv -n 30 --no-pager"
    ALL_OK=false
  fi
done

echo ""

# ============================================================================
# Section 11 — Print access URLs
# ============================================================================
cat << 'EOF'
========================================
Vuln Observability Stack — Access URLs
========================================
Grafana:       http://3.219.30.122:3000  (admin/admin)
Prometheus:    http://3.219.30.122:9090
Alertmanager:  http://3.219.30.122:9093
Loki:          http://3.219.30.122:3100
Tempo:         http://3.219.30.122:3200
Demo Service:  http://3.219.30.122:8080
========================================
EOF

if [ "$ALL_OK" = "false" ]; then
  echo "[NOTE] Some services failed. Use the journalctl commands above to diagnose each one."
fi

exit 0
