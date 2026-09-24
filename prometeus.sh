#!/bin/bash

set -e

PROMETHEUS_VERSION="3.14.0"
LOGS_FILE="/var/log/prometheus-install.log"

# Create Prometheus system user
useradd --system --no-create-home --shell /sbin/nologin prometheus 2>/dev/null || true

cd /opt

# Remove old archive
rm -f prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

# Download Prometheus
curl -sL \
  -o prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
  &>> "$LOGS_FILE"

# Extract
tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz \
  &>> "$LOGS_FILE"

# Create stable symbolic link
ln -sfn \
  /opt/prometheus-${PROMETHEUS_VERSION}.linux-amd64 \
  /opt/prometheus

# Create Prometheus TSDB data directory
mkdir -p /var/lib/prometheus

# Set ownership
chown -R prometheus:prometheus \
  /opt/prometheus-${PROMETHEUS_VERSION}.linux-amd64

chown -R prometheus:prometheus /var/lib/prometheus

# Create systemd service
cat > /etc/systemd/system/prometheus.service <<'UNIT'
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
User=prometheus
Group=prometheus
Restart=on-failure

ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
UNIT

# Reload systemd
systemctl daemon-reload

# Enable and start Prometheus
systemctl enable --now prometheus

# Check status
systemctl status prometheus --no-pager
