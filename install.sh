#!/bin/bash
# MQTT Doorbell Notifier - Installer

set -e

SCRIPT_NAME="doorbell-notifier.sh"
INSTALL_DIR="$HOME/.local/bin"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="doorbell-notifier.service"

echo "MQTT Doorbell Notifier - Installer"
echo "=================================="
echo ""

# Check for a single dependency
# Usage: check_dependency "command_name" "package_name"
check_dependency() {
  local cmd=$1
  local pkg=$2

  if ! command -v "$cmd" &> /dev/null; then
    MISSING_DEPS+=("$cmd")
    MISSING_PACKAGES+=("$pkg")
  fi
}

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=()
MISSING_PACKAGES=()

check_dependency "mosquitto_sub" "mosquitto-clients"
check_dependency "secret-tool" "libsecret-tools"
check_dependency "notify-send" "libnotify-bin"
check_dependency "canberra-gtk-play" "gnome-session-canberra"

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
  {
    echo "Error: Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Install with:"
    echo "  sudo apt install ${MISSING_PACKAGES[*]}"
    echo ""
    echo "Or see README.md for more information."
  } >&2
  exit 1
fi

echo "All dependencies found."
echo ""

# Check if script exists
if [ ! -f "$SCRIPT_NAME" ]; then
  {
    echo "Error: $SCRIPT_NAME not found in current directory."
    echo "Please run this installer from the repository directory."
  } >&2
  exit 1
fi

# Install script
echo "Installing script to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo ""
  echo "Warning: $HOME/.local/bin is not in your PATH."
  echo "Add this line to your ~/.bashrc or ~/.profile:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
  echo ""
  echo "Then run: source ~/.bashrc"
fi

# Install service
echo "Installing systemd user service..."
mkdir -p "$SERVICE_DIR"
cp "$SERVICE_NAME" "$SERVICE_DIR/"

# Reload systemd
systemctl --user daemon-reload

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║         Installation completed successfully!          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "  1. Configure MQTT settings:"
echo "     $ $SCRIPT_NAME -c"
echo ""
echo "  2. Enable the service to start on login:"
echo "     $ systemctl --user enable $SERVICE_NAME"
echo ""
echo "  3. Start the service now:"
echo "     $ systemctl --user start $SERVICE_NAME"
echo ""
echo "  4. Check status:"
echo "     $ systemctl --user status $SERVICE_NAME"
echo ""
echo "  5. View logs:"
echo "     $ journalctl --user -u $SERVICE_NAME -f"
echo ""
echo "For more information, see README.md"
echo ""
