#!/bin/bash
set -e
USER="rezndsl"
GROUP="rezndsl"
ENV_FILE="/etc/rezndsl/rezndsl.env"
DEFAULT_ENV_FILE="/etc/rezndsl/rezndsl.env.default"
CONFIG_DIR="/etc/rezndsl"
LOG_DIR="/var/log/rezndsl"
SERVICE_NAME="rezndsl.service"

if [ -f "/lib/systemd/system/$SERVICE_NAME" ]; then
  systemctl stop "$SERVICE_NAME" || true
  systemctl disable "$SERVICE_NAME" || true
  rm -f "/lib/systemd/system/$SERVICE_NAME"
  systemctl daemon-reload
fi

echo "Removing rezndsl-cli symlinks..." 
rm -f /usr/local/bin/reznc
rm -f /usr/local/bin/rezn-verify

if [ "$1" = "purge" ]; then
  echo "--- Starting purge actions ---"

  echo "Removing $ENV_FILE (if it exists)..."
  [ -f "$ENV_FILE" ] && rm -f "$ENV_FILE"
  echo "Removed $ENV_FILE (or it didn't exist)."

  echo "Removing $DEFAULT_ENV_FILE (if it exists)..."
  [ -f "$DEFAULT_ENV_FILE" ] && rm -f "$DEFAULT_ENV_FILE"
  echo "Removed $DEFAULT_ENV_FILE (or it didn't exist)."

  echo "Attempting to remove directory $CONFIG_DIR..."
  if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
  else
    echo "$CONFIG_DIR does not exist."
  fi

  echo "Attempting to remove directory $LOG_DIR..."
  if [ -d "$LOG_DIR" ]; then
    if rm -rf "$LOG_DIR"; then
      echo "$LOG_DIR removed successfully."
    else
      echo "Error removing $LOG_DIR."
    fi
  else
    echo "$LOG_DIR does not exist."
  fi

  echo "Attempting to remove user $USER..."
  if id -u "$USER" &>/dev/null; then
    userdel "$USER" || true
    echo "User $USER deleted."
  else
    echo "User $USER does not exist."
  fi

  echo "Attempting to remove group $GROUP..."
  if getent group "$GROUP" &>/dev/null; then
    groupdel "$GROUP" || true
    echo "Group $GROUP removed successfully."
  else
    echo "Group $GROUP does not exist."
  fi

  echo "--- Purge actions finished ---"
fi
