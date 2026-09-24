#!/bin/bash

set -e

PROMETHEUS_VERSION="3.14.0"
LOGS_FILE="/var/log/prometheus-install.log"

useradd --system --no-create-home --shell /sbin/nologin prometheus 2>/dev/null || true

cd /opt

rm -f prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

curl -sL \
  -o prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
  &>> "$LOGS_FILE"

tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz \
  &>> "$LOGS_FILE"

ln -sfn \
  /opt/prometheus-${PROMETHEUS_VERSION}.linux-amd64 \
  /opt/prometheus

chown -R prometheus:prometheus \
  /opt/prometheus-${PROMETHEUS_VERSION}.linux-amd64

cat > /etc/systemd/system/prometheus.service <<'UNIT'
[Unit]
Description=Prometheus Server
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Restart=on-failure
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now prometheus
