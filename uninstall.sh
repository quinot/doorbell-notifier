#!/bin/bash
# MQTT Doorbell Notifier - Uninstaller

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="doorbell-notifier.service"

echo "MQTT Doorbell Notifier - Uninstaller"
echo "====================================="
echo ""

# Check if service is running
if systemctl --user is-active --quiet $SERVICE_NAME; then
  echo "Stopping service..."
  systemctl --user stop $SERVICE_NAME
fi

# Check if service is enabled
if systemctl --user is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
  echo "Disabling service..."
  systemctl --user disable $SERVICE_NAME
fi

# Remove service file
echo "Removing service file..."
rm -f "$SERVICE_DIR/$SERVICE_NAME"

# Reload systemd
systemctl --user daemon-reload

# Uninstall via pipx
echo "Uninstalling doorbell-notifier via pipx..."
pipx uninstall doorbell-notifier

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║        Uninstallation completed successfully!         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Note: Configuration file was NOT removed."
echo ""
echo "To remove configuration:"
echo "  $ rm -rf ~/.config/doorbell-notifier"
echo ""
