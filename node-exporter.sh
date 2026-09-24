#!/bin/bash

set -e

NODE_EXPORTER_VERSION="1.12.1"
LOGS_FILE="/var/log/node_exporter-install.log"

echo "Installing Node Exporter..." | tee -a "$LOGS_FILE"

# Create service user
useradd --system --no-create-home --shell /sbin/nologin node_exporter 2>/dev/null || true

cd /opt

# Remove old archive if present
rm -f node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

# Download Node Exporter
curl -sL \
  -o node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" \
  &>> "$LOGS_FILE"

# Extract
tar -xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz \
  &>> "$LOGS_FILE"

# Create stable symbolic link
ln -sfn \
  /opt/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64 \
  /opt/node_exporter

# Set ownership
chown -R node_exporter:node_exporter \
  /opt/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

# Create systemd service
cat > /etc/systemd/system/node_exporter.service <<'UNIT'
[Unit]
Description=Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Restart=on-failure
ExecStart=/opt/node_exporter/node_exporter

[Install]
WantedBy=multi-user.target
UNIT

# Reload systemd
systemctl daemon-reload

# Enable and start Node Exporter
systemctl enable --now node_exporter

echo "Node Exporter installation completed."

systemctl status node_exporter --no-pager
