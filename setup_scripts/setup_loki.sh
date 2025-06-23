#!/bin/bash

# NOTE: This script is tested on Ubuntu 22.04 LTS.
# It doesnt have any ubuntu/debian based dependencies like apt, so it should work on any linux distro with minimal changes.
# Prod system most likely has Ubuntu server

set -euo pipefail

LOKI_VERSION="3.5.0"
LOKI_USER="loki"
LOKI_GROUP="loki"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/loki"
DATA_DIR="/var/lib/loki"
SERVICE_FILE="/etc/systemd/system/loki.service"
LOKI_BINARY="/usr/local/bin/loki"
TEMPLATE_DIR="$(dirname "$0")"
FORCE_INSTALL=false

if [[ "${1:-}" == "--force" ]]; then
  FORCE_INSTALL=true
fi

echo "[INFO] Setting up Loki ${LOKI_VERSION}"

# === User/Group Setup ===
if ! id -u "$LOKI_USER" &>/dev/null; then
  useradd --no-create-home --system --shell /bin/false "$LOKI_USER"
  echo "[INFO] Created user $LOKI_USER"
fi

mkdir -p "$CONFIG_DIR" "$DATA_DIR"
chown -R "$LOKI_USER:$LOKI_GROUP" "$CONFIG_DIR" "$DATA_DIR"

# === Loki Binary Installation ===
if command -v loki &>/dev/null && ! $FORCE_INSTALL; then
  echo "[INFO] Loki is already installed. Use --force to reinstall."
else
  echo "[INFO] Downloading Loki..."
  wget -qO /tmp/loki.zip "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
  unzip -qo /tmp/loki.zip -d /tmp/
  mv /tmp/loki-linux-amd64 "$LOKI_BINARY"
  chmod +x "$LOKI_BINARY"
  echo "[INFO] Loki installed at $LOKI_BINARY"
fi

# === Configuration File ===
LOKI_CONFIG_FILE="$CONFIG_DIR/loki-config.yaml"
if [[ ! -f "$LOKI_CONFIG_FILE" || $FORCE_INSTALL == true ]]; then
  echo "[INFO] Writing config to $LOKI_CONFIG_FILE"
  envsubst < "$TEMPLATE_DIR/loki-config.yaml.template" > "$LOKI_CONFIG_FILE"
  chown "$LOKI_USER:$LOKI_GROUP" "$LOKI_CONFIG_FILE"
else
  echo "[INFO] Config already exists. Use --force to overwrite."
fi

# === systemd Service ===
echo "[INFO] Installing systemd service..."
envsubst < "$TEMPLATE_DIR/loki.service.template" > "$SERVICE_FILE"
chmod 644 "$SERVICE_FILE"

# === Start Loki ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now loki

echo "[✅] Loki service installed and running."
echo "[ℹ️ ] Config: $LOKI_CONFIG_FILE"
