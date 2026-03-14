#!/bin/bash
# MQTT Doorbell Notifier - Installer

set -e

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

# Check for a Python GI package (by trying to import it)
# Usage: check_gi_package "gi_module" "package_name"
check_gi_package() {
  local module=$1
  local pkg=$2

  if ! python3 -c "import $module" &> /dev/null; then
    MISSING_DEPS+=("$module")
    MISSING_PACKAGES+=("$pkg")
  fi
}

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=()
MISSING_PACKAGES=()

check_dependency "pipx" "pipx"
check_gi_package "gi" "python3-gi"

# Check GI typelibs by trying to require them
if ! python3 -c "import gi; gi.require_version('Notify','0.7'); from gi.repository import Notify" &> /dev/null; then
  MISSING_DEPS+=("gir1.2-notify-0.7")
  MISSING_PACKAGES+=("gir1.2-notify-0.7")
fi

if ! python3 -c "import gi; gi.require_version('GSound','1.0'); from gi.repository import GSound" &> /dev/null; then
  MISSING_DEPS+=("gir1.2-gsound-1.0")
  MISSING_PACKAGES+=("gir1.2-gsound-1.0")
fi

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

# Install via pipx
echo "Installing doorbell-notifier via pipx..."
pipx install --system-site-packages .

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
echo "     $ doorbell-notifier -c"
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
