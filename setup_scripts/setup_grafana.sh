#!/bin/bash

# NOTE: This script is tested on Ubuntu 22.04 LTS.
# It doesnt have any ubuntu/debian based dependencies like apt, so it should work on any linux distro with minimal changes.
# Prod system most likely has Ubuntu server

set -euo pipefail

GRAFANA_VERSION="12.0.2"
GRAFANA_USER="grafana"
GRAFANA_GROUP="grafana"
INSTALL_DIR="/usr/share/grafana"
CONFIG_DIR="/etc/grafana"
DATA_DIR="/var/lib/grafana"
LOG_DIR="/var/log/grafana"
SERVICE_FILE="/etc/systemd/system/grafana.service"
ENV_FILE="/etc/default/grafana"
ARCHIVE_URL="https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz"
ARCHIVE_NAME="/tmp/grafana.tar.gz"
FORCE_INSTALL=false

if [[ "${1:-}" == "--force" ]]; then
  FORCE_INSTALL=true
fi

echo "[INFO] Installing Grafana ${GRAFANA_VERSION}..."

# === Create user/group ===
if ! getent group "$GRAFANA_GROUP" > /dev/null; then
  groupadd --system "$GRAFANA_GROUP"
fi
if ! id -u "$GRAFANA_USER" &>/dev/null; then
  useradd --system --home "$INSTALL_DIR" --shell /sbin/nologin --gid "$GRAFANA_GROUP" "$GRAFANA_USER"
fi

# === Download and extract ===
if [[ -d "$INSTALL_DIR" && $FORCE_INSTALL == false ]]; then
  echo "[INFO] Grafana already installed. Use --force to reinstall."
else
  wget -qO "$ARCHIVE_NAME" "$ARCHIVE_URL"
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  tar -xzf "$ARCHIVE_NAME" -C /tmp
  mv /tmp/grafana-*/* "$INSTALL_DIR"
  rm -f "$ARCHIVE_NAME"
fi

# === Create dirs and permissions ===
mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
chown -R "$GRAFANA_USER:$GRAFANA_GROUP" "$INSTALL_DIR" "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"

# === Copy config ===
if [[ ! -f "$CONFIG_DIR/grafana.ini" || $FORCE_INSTALL == true ]]; then
  cp "$INSTALL_DIR/conf/defaults.ini" "$CONFIG_DIR/grafana.ini"
  chown "$GRAFANA_USER:$GRAFANA_GROUP" "$CONFIG_DIR/grafana.ini"
fi

# === Deploy environment and service files ===
echo "[INFO] Installing systemd and environment files..."
cp ./grafana_files/grafana.env.template "$ENV_FILE"
cp ./grafana_files/grafana.service.template "$SERVICE_FILE"
chmod 644 "$SERVICE_FILE" "$ENV_FILE"

# === Enable and start service ===
systemctl daemon-reload
systemctl enable grafana.service
systemctl restart grafana.service

echo "[✅] Grafana installed successfully!"
echo "[ℹ️ ] Access it at http://localhost:3000"
