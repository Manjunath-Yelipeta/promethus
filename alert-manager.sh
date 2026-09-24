#!/bin/bash

set -e

ALERTMANAGER_VERSION="0.34.1"

cd /opt

# Download Alertmanager
wget https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz

# Extract
tar -xzf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz

# Create stable symlink
ln -sfn \
  /opt/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64 \
  /opt/alertmanager

# Create service user
useradd --system --no-create-home --shell /sbin/nologin alertmanager 2>/dev/null || true

# Create data directory
mkdir -p /var/lib/alertmanager

# Set ownership
chown -R alertmanager:alertmanager \
  /opt/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64

chown -R alertmanager:alertmanager \
  /var/lib/alertmanager

# Create minimal Alertmanager config
cat > /opt/alertmanager/alertmanager.yml <<'EOF'
route:
  receiver: default

receivers:
  - name: default
EOF

# Create systemd service
cat > /etc/systemd/system/alertmanager.service <<'UNIT'
[Unit]
Description=Alertmanager
Documentation=https://prometheus.io/docs/alerting/latest/alertmanager/
After=network-online.target
Wants=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Restart=on-failure
ExecStart=/opt/alertmanager/alertmanager \
  --config.file=/opt/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager

[Install]
WantedBy=multi-user.target
UNIT

# Reload systemd
systemctl daemon-reload

# Enable and start Alertmanager
systemctl enable --now alertmanager

# Check status
systemctl status alertmanager --no-pager
