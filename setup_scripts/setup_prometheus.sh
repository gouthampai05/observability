#!/bin/bash

# NOTE: This script is tested on Ubuntu 22.04 LTS.
# It doesnt have any ubuntu/debian based dependencies like apt, so it should work on any linux distro with minimal changes.
# Prod system most likely has Ubuntu server

set -euo pipefail

# === Configuration ===
PROMETHEUS_VERSION="3.4.1"
USER="prometheus"
GROUP="prometheus"
INSTALL_DIR="/opt/prometheus"
DATA_DIR="/var/lib/prometheus"
CONFIG_DIR="/etc/prometheus"
BIN_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/prometheus.service"
TEMPLATE_DIR="$(dirname "$0")"
FORCE_INSTALL=false

# Parse optional --force flag
if [[ "${1:-}" == "--force" ]]; then
  FORCE_INSTALL=true
fi

echo "[INFO] Installing Prometheus v${PROMETHEUS_VERSION}"

# === Create user and directories ===
if ! id "$USER" &>/dev/null; then
    useradd --no-create-home --shell /usr/sbin/nologin "$USER"
    echo "[INFO] Created user $USER"
fi

mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$CONFIG_DIR"
chown -R "$USER:$GROUP" "$INSTALL_DIR" "$DATA_DIR" "$CONFIG_DIR"

# === Download and install Prometheus ===
if [[ ! -x "$BIN_DIR/prometheus" || $FORCE_INSTALL == true ]]; then
    echo "[INFO] Downloading Prometheus..."
    cd /tmp
    curl -sLO "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
    tar -xzf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

    # Detect extracted folder
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "prometheus-${PROMETHEUS_VERSION}.linux-amd64" | head -n1)

    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        echo "[ERROR] Failed to extract Prometheus archive."
        exit 1
    fi

    cd "$EXTRACTED_DIR"

    cp prometheus promtool "$BIN_DIR/"
    chmod +x "$BIN_DIR/prometheus" "$BIN_DIR/promtool"

    # Only copy consoles if they exist
    if [[ -d "consoles" && -d "console_libraries" ]]; then
        cp -r consoles console_libraries "$INSTALL_DIR/"
    else
        echo "[WARN] consoles/ or console_libraries/ missing in the archive. Skipping copy."
    fi

    echo "[INFO] Prometheus binaries installed to $BIN_DIR"
else
    echo "[INFO] Prometheus already installed. Use --force to reinstall."
fi


# === Config ===
PROM_CONFIG="$CONFIG_DIR/prometheus.yml"
if [[ ! -f "$PROM_CONFIG" || $FORCE_INSTALL == true ]]; then
    echo "[INFO] Generating Prometheus config..."
    envsubst < "$TEMPLATE_DIR/prometheus.yml.template" > "$PROM_CONFIG"
    chown "$USER:$GROUP" "$PROM_CONFIG"
else
    echo "[INFO] Config already exists. Use --force to overwrite."
fi

# === Validate Config ===
echo "[INFO] Validating configuration..."
promtool check config "$PROM_CONFIG"

# === systemd Service ===
echo "[INFO] Creating Prometheus systemd service..."
envsubst < "$TEMPLATE_DIR/prometheus.service.template" > "$SERVICE_FILE"
chmod 644 "$SERVICE_FILE"

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable prometheus

# === Start Service ===
echo "[INFO] Starting Prometheus..."
systemctl start prometheus
systemctl status prometheus --no-pager

echo "[✅ SUCCESS] Prometheus is running at http://localhost:9090"
