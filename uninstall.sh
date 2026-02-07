#!/bin/bash
# MQTT Doorbell Listener - Uninstaller

SCRIPT_NAME="doorbell-notifier.sh"
INSTALL_DIR="$HOME/.local/bin"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="doorbell-notifier.service"

echo "MQTT Doorbell Listener - Uninstaller"
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

# Remove files
echo "Removing files..."
rm -f "$INSTALL_DIR/$SCRIPT_NAME"
rm -f "$SERVICE_DIR/$SERVICE_NAME"

# Reload systemd
systemctl --user daemon-reload

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║        Uninstallation completed successfully!         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Note: Configuration stored in keyring was NOT removed."
echo ""
echo "To remove MQTT configuration from keyring:"
echo "  $ secret-tool clear service mqtt field url"
echo "  $ secret-tool clear service mqtt field topic"
echo "  $ secret-tool clear service mqtt field username"
echo "  $ secret-tool clear service mqtt field password"
echo "  $ secret-tool clear service mqtt field clientid"
echo ""
echo "Or use the GUI: Passwords and Keys (Seahorse)"
echo ""
