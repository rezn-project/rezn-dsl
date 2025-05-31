#!/bin/bash
set -e
ENV_FILE="/etc/rezndsl/rezndsl.env"
DEFAULT_ENV_FILE="/etc/rezndsl/rezndsl.env.default"
SERVICE_NAME="rezndsl.service"
USER="rezndsl"
GROUP="rezndsl"

if ! getent group "$GROUP" >/dev/null; then
  echo "Creating group $GROUP" 
  groupadd --system "$GROUP"
fi

if ! id -u "$USER" >/dev/null 2>&1; then
  echo "Creating user $USER" 
  useradd --system --no-create-home --shell /usr/sbin/nologin --gid "$GROUP" "$USER"
fi

mkdir -p /etc/rezndsl
chown "$USER:$GROUP" /etc/rezndsl
chmod 700 /etc/rezndsl

echo "Installing default environment template at $DEFAULT_ENV_FILE"
chown "$USER:$GROUP" "$DEFAULT_ENV_FILE"
chmod 644 "$DEFAULT_ENV_FILE"

if [ ! -f "$ENV_FILE" ]; then
  echo "Generating initial environment config at $ENV_FILE"
  cp "$DEFAULT_ENV_FILE" "$ENV_FILE"

  chown "$USER:$GROUP" "$ENV_FILE"
  chmod 640 "$ENV_FILE"
else
  echo "Environment file already exists, preserving values"
  NEW_KEYS=$(grep -E '^[A-Z0-9_]+=' "$DEFAULT_ENV_FILE" | cut -d= -f1)
  for key in $NEW_KEYS; do
    if ! grep -q "^$key=" "$ENV_FILE"; then
      echo "WARNING: Missing key '$key' in your rezndsl.env"
    fi
  done
fi

ln -sf /opt/rezndsl-cli/bin/reznc /usr/local/bin/reznc
ln -sf /opt/rezndsl-cli/bin/rezn-verify /usr/local/bin/rezn-verify

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"