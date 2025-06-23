#!/bin/bash

# NOTE: This script is tested on Ubuntu 22.04 LTS.
# Unlike other scripts, this one HAS ubuntu/debian based dependencies like apt.
# so it may require changes to work on non-debian based distros.

set -e

# === Usage check ===
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/nginx.conf.template"
    exit 1
fi

TEMPLATE_PATH="$1"

# === CONFIG: Customize these ===
DOMAIN="metrics.example.com"
TLS_CERT_PATH="/etc/nginx/ssl/fullchain.pem"
TLS_KEY_PATH="/etc/nginx/ssl/privkey.pem"
PROMETHEUS_UPSTREAM="http://localhost:9090"
LOKI_UPSTREAM="http://localhost:3100"
USE_TLS=true
USE_BASIC_AUTH=true
AUTH_USER="admin"
AUTH_PASS="supersecurepassword"

NGINX_CONF_DEST="/etc/nginx/sites-available/metrics"

# === Install nginx and utils ===
echo "Installing NGINX and utils..."
sudo apt update
sudo apt install -y nginx apache2-utils

# === Setup basic auth ===
AUTH_BLOCK=""
if [ "$USE_BASIC_AUTH" = true ]; then
    echo "Creating basic auth..."
    sudo mkdir -p /etc/nginx/auth
    echo "$AUTH_PASS" | sudo htpasswd -ci /etc/nginx/auth/metrics.htpasswd "$AUTH_USER"
    
    # Use actual newlines with a heredoc
    AUTH_BLOCK=$(cat <<EOF
auth_basic "Restricted";
auth_basic_user_file /etc/nginx/auth/metrics.htpasswd;
EOF
)
fi


# === TLS Redirect ===
if [ "$USE_TLS" = true ]; then
    REDIRECT_TO_HTTPS="return 301 https://\$host\$request_uri;"
else
    REDIRECT_TO_HTTPS=""
fi

# === Generate nginx config from template ===
echo "Generating NGINX config from template..."
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
CONFIG_CONTENT=$(<"$TEMPLATE_PATH")
CONFIG_CONTENT="${CONFIG_CONTENT//'{{DOMAIN}}'/$DOMAIN}"
CONFIG_CONTENT="${CONFIG_CONTENT//'{{TLS_CERT_PATH}}'/$TLS_CERT_PATH}"
CONFIG_CONTENT="${CONFIG_CONTENT//'{{TLS_KEY_PATH}}'/$TLS_KEY_PATH}"
CONFIG_CONTENT="${CONFIG_CONTENT//'{{PROMETHEUS_UPSTREAM}}'/$PROMETHEUS_UPSTREAM}"
CONFIG_CONTENT="${CONFIG_CONTENT//'{{LOKI_UPSTREAM}}'/$LOKI_UPSTREAM}"
CONFIG_CONTENT="${CONFIG_CONTENT//'{{AUTH_BLOCK}}'/$AUTH_BLOCK}"
CONFIG_CONTENT="${CONFIG_CONTENT//'{{REDIRECT_TO_HTTPS}}'/$REDIRECT_TO_HTTPS}"

echo "$CONFIG_CONTENT" | sudo tee "$NGINX_CONF_DEST" > /dev/null
sudo ln -sf "$NGINX_CONF_DEST" /etc/nginx/sites-enabled/metrics

# === Test and reload NGINX ===
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "✅ NGINX is set up at https://$DOMAIN"
if [ "$USE_BASIC_AUTH" = true ]; then
    echo "🔐 Basic auth enabled — user: $AUTH_USER"
fi
