#!/bin/bash
# ============================================================================
# Section 0 — Strict mode and variables
# ============================================================================
set -euo pipefail

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

# ============================================================================
# Section 1 — System preparation
# ============================================================================
echo "==> Preparing system..."
apt-get update -y
apt-get install -y curl wget tar unzip python3 python3-pip python3-venv adduser libfontconfig1 apt-transport-https software-properties-common

# Add Grafana apt repository and install grafana=10.4.2
if ! dpkg -l | grep -q grafana; then
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /usr/share/keyrings/grafana.gpg
  echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
  apt-get update -y
  apt-get install -y grafana=10.4.2
fi

systemctl daemon-reload

# ============================================================================
# Section 2 — Create system users
# ============================================================================
echo "==> Creating system users..."
for user in prometheus loki tempo node_exporter blackbox alertmanager otel ghexporter; do
  if ! id -u "$user" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /bin/false "$user"
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

mkdir -p ${CONFIG_BASE}/otel-collector
mkdir -p ${CONFIG_BASE}/blackbox-exporter
mkdir -p ${CONFIG_BASE}/github-actions-exporter
mkdir -p /var/log/demo-service

# ============================================================================
# Section 4 — Download and install binaries
# ============================================================================
echo "==> Downloading and installing binaries..."
# Use /var/tmp which is usually backed by disk, not a small RAM tmpfs
TMP_DIR=$(mktemp -d -p /var/tmp)
cd "$TMP_DIR"

# Prometheus
if [ ! -f "${INSTALL_DIR}/prometheus" ]; then
  wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
  tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
  cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus ${INSTALL_DIR}/
  cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/prometheus ${INSTALL_DIR}/promtool
  rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*
fi

# Loki
if [ ! -f "${INSTALL_DIR}/loki" ]; then
  wget -q "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
  unzip loki-linux-amd64.zip
  mv loki-linux-amd64 loki
  cp loki ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/loki
  rm -rf loki*
fi

# Tempo
if [ ! -f "${INSTALL_DIR}/tempo" ]; then
  wget -q "https://github.com/grafana/tempo/releases/download/v${TEMPO_VERSION}/tempo_${TEMPO_VERSION}_linux_amd64.tar.gz"
  tar xvf tempo_${TEMPO_VERSION}_linux_amd64.tar.gz
  cp tempo ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/tempo
  rm -rf tempo*
fi

# Node Exporter
if [ ! -f "${INSTALL_DIR}/node_exporter" ]; then
  wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
  tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
  cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/node_exporter
  rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
fi

# Blackbox Exporter
if [ ! -f "${INSTALL_DIR}/blackbox_exporter" ]; then
  wget -q "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz"
  tar xvf blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz
  cp blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64/blackbox_exporter ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/blackbox_exporter
  rm -rf blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64*
fi

# Alertmanager
if [ ! -f "${INSTALL_DIR}/alertmanager" ]; then
  wget -q "https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz"
  tar xvf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
  cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/alertmanager ${INSTALL_DIR}/
  cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/amtool ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/alertmanager ${INSTALL_DIR}/amtool
  rm -rf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64*
fi

# OTel Collector
if [ ! -f "${INSTALL_DIR}/otelcol-contrib" ]; then
  wget -q "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_amd64.tar.gz"
  tar xvf otelcol-contrib_${OTEL_VERSION}_linux_amd64.tar.gz
  cp otelcol-contrib ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/otelcol-contrib
  rm -rf otelcol-contrib*
fi

# GitHub Actions Exporter
if [ ! -f "${INSTALL_DIR}/github-actions-exporter" ]; then
  wget -q "https://github.com/cpanato/github-actions-exporter/releases/download/v${GH_EXPORTER_VERSION}/github-actions-exporter_${GH_EXPORTER_VERSION}_Linux_x86_64.tar.gz"
  tar xvf github-actions-exporter_${GH_EXPORTER_VERSION}_Linux_x86_64.tar.gz
  cp github-actions-exporter ${INSTALL_DIR}/
  chmod 755 ${INSTALL_DIR}/github-actions-exporter
  rm -rf github-actions-exporter*
fi

cd "$REPO_DIR"
rm -rf "$TMP_DIR"

# ============================================================================
# Section 5 — Copy config files from repo to system paths
# ============================================================================
echo "==> Copying configuration files..."
cp $REPO_DIR/prometheus/prometheus.yml /etc/prometheus/prometheus.yml
cp $REPO_DIR/prometheus/blackbox.yml /etc/blackbox-exporter/config.yml
cp -r $REPO_DIR/prometheus/rules/* /etc/prometheus/rules/
cp $REPO_DIR/loki/loki-config.yml /etc/loki/loki-config.yml
cp $REPO_DIR/tempo/tempo-config.yml /etc/tempo/tempo-config.yml
cp $REPO_DIR/alertmanager/alertmanager.yml /etc/alertmanager/alertmanager.yml
cp -r $REPO_DIR/alertmanager/templates/* /etc/alertmanager/templates/
cp $REPO_DIR/otel-collector/otel-collector-config.yml /etc/otel-collector/config.yml

# Copy grafana directory preserving structure
cp -r $REPO_DIR/grafana/* /etc/grafana/

echo "==> Setting permissions..."
# Config directories ownership
chown -R prometheus:prometheus /etc/prometheus
chown -R loki:loki /etc/loki
chown -R tempo:tempo /etc/tempo
chown -R alertmanager:alertmanager /etc/alertmanager
chown -R blackbox:blackbox /etc/blackbox-exporter
chown -R otel:otel /etc/otel-collector
chown -R ghexporter:ghexporter /etc/github-actions-exporter

# Data directories ownership
chown -R prometheus:prometheus /var/lib/prometheus
chown -R loki:loki /var/lib/loki
chown -R tempo:tempo /var/lib/tempo
chown -R alertmanager:alertmanager /var/lib/alertmanager

# ============================================================================
# Section 6 — Substitute environment variables in alertmanager config
# ============================================================================
echo "==> Substituting environment variables..."
sed -i "s|PLACEHOLDER|${SLACK_WEBHOOK_URL}|g" /etc/alertmanager/alertmanager.yml

# For github-actions-exporter systemd unit
sed -i "s|placeholder_token|${GITHUB_PAT}|g" /etc/systemd/system/github-actions-exporter.service || true

# ============================================================================
# Section 7 — Install and configure demo service
# ============================================================================
echo "==> Installing demo service..."
mkdir -p /opt/demo-service
cp $REPO_DIR/demo-service/app.py /opt/demo-service/
cp $REPO_DIR/demo-service/requirements.txt /opt/demo-service/

python3 -m venv /opt/demo-service/venv
/opt/demo-service/venv/bin/pip install -r /opt/demo-service/requirements.txt

if ! id -u "demoservice" >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /bin/false demoservice
fi

chown -R demoservice:demoservice /opt/demo-service

# ============================================================================
# Section 8 — Install systemd unit files
# ============================================================================
echo "==> Installing systemd unit files..."
cp $REPO_DIR/systemd/*.service /etc/systemd/system/
systemctl daemon-reload

# ============================================================================
# Section 9 — Enable and start all services
# ============================================================================
echo "==> Enabling and starting services..."

# We must do grafana-server explicitly since it's installed via apt
SERVICES="grafana-server prometheus loki tempo node-exporter blackbox-exporter alertmanager otel-collector github-actions-exporter demo-service"

for srv in $SERVICES; do
  systemctl enable $srv
  systemctl start $srv
done

# ============================================================================
# Section 10 — Health verification
# ============================================================================
echo "==> Waiting 10 seconds for services to initialize..."
sleep 10

echo "==> Service Health Verification:"
for srv in $SERVICES; do
  STATUS=$(systemctl is-active $srv || true)
  if [ "$STATUS" = "active" ]; then
    echo "  [ OK ] $srv is active"
  else
    echo "  [FAIL] $srv is $STATUS"
  fi
done

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

exit 0
