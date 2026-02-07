#!/bin/bash
#
# MQTT Doorbell Notification Script
#
# This script subscribes to an MQTT topic and displays desktop notifications
# when messages are received (e.g., when a doorbell button is pressed).
#
# USAGE:
#   ./doorbell-notifier.sh           Run the doorbell notifier
#   ./doorbell-notifier.sh -c        Configure MQTT settings interactively
#   ./doorbell-notifier.sh -v        View current configuration
#   ./doorbell-notifier.sh -h        Show help
#
# CONFIGURATION:
# All configuration is stored in the system keyring using secret-tool.
# You can manage it with:
#   - The configuration wizard: ./doorbell-notifier.sh -c
#   - View current values: ./doorbell-notifier.sh -v
#   - GUI tool: seahorse (Passwords and Keys)
#
# Manual configuration with secret-tool:
#   secret-tool store --label='MQTT Doorbell URL' service mqtt field url
#   secret-tool store --label='MQTT Doorbell Topic' service mqtt field topic
#   secret-tool store --label='MQTT Doorbell Username' service mqtt field username
#   secret-tool store --label='MQTT Doorbell Password' service mqtt field password
#   secret-tool store --label='MQTT Doorbell Client ID' service mqtt field clientid

# Configuration field definitions
declare -A CONFIG_FIELDS=(
  [url]="MQTT Doorbell URL"
  [topic]="MQTT Doorbell Topic"
  [username]="MQTT Doorbell Username"
  [password]="MQTT Doorbell Password"
  [clientid]="MQTT Doorbell Client ID"
)

declare -A CONFIG_REQUIRED=(
  [url]=1
  [topic]=1
  [username]=1
  [password]=1
  [clientid]=0
)

# Retrieve a configuration value from keyring
get_config() {
  local field=$1
  secret-tool lookup service mqtt field "$field" 2>/dev/null
}

# Store a configuration value in keyring
set_config() {
  local field=$1
  local value=$2
  local label="${CONFIG_FIELDS[$field]}"
  echo "$value" | secret-tool store --label="$label" service mqtt field "$field"
}

# Prompt for a configuration value
prompt_config() {
  local field=$1
  local prompt_text=$2
  local is_password=$3
  local current_value
  local value

  current_value=$(get_config "$field")

  # Display current value to stderr so it doesn't get captured
  if [ -n "$current_value" ] && [ "$is_password" != "1" ]; then
    echo "Current value: $current_value" >&2
  elif [ -n "$current_value" ] && [ "$is_password" = "1" ]; then
    echo "Current value: (hidden)" >&2
  fi

  if [ "$is_password" = "1" ]; then
    read -sp "$prompt_text: " value >&2
    echo "" >&2
  else
    read -p "$prompt_text: " value >&2
  fi

  # Output only the value to stdout
  echo "$value"
}

# Show help message
show_help() {
  cat << EOF
MQTT Doorbell Notification Script

USAGE:
  $0              Run the doorbell notifier
  $0 -c           Configure MQTT settings interactively
  $0 -v           View current configuration
  $0 -h           Show this help message

EXAMPLES:
  $0 -c           # Configure settings
  $0 -v           # View current settings
  $0              # Run the notifier

MQTT URL FORMATS:
  mqtt://host:1883              Plain MQTT
  mqtts://host:8883             MQTT with TLS
  ws://host:9001/mqtt           MQTT over WebSockets
  wss://host:9001/mqtt          MQTT over secure WebSockets

EOF
}

# View current configuration
view_config() {
  echo "Current MQTT Doorbell Configuration"
  echo "===================================="
  echo ""

  local has_config=0

  for field in url topic username clientid; do
    local value=$(get_config "$field")
    local label="${CONFIG_FIELDS[$field]}"

    if [ -n "$value" ]; then
      echo "$label: $value"
      has_config=1
    else
      echo "$label: (not set)"
    fi
  done

  # Special handling for password
  local password=$(get_config "password")
  if [ -n "$password" ]; then
    echo "${CONFIG_FIELDS[password]}: (hidden)"
    has_config=1
  else
    echo "${CONFIG_FIELDS[password]}: (not set)"
  fi

  echo ""

  if [ $has_config -eq 0 ]; then
    echo "No configuration found. Run '$0 -c' to configure."
    return 1
  fi

  return 0
}

# Configure settings interactively
configure() {
  echo "MQTT Doorbell Configuration"
  echo "==========================="
  echo ""

  # Prompt for URL
  echo "MQTT Broker URL"
  echo "Examples: mqtt://192.168.1.100:1883"
  echo "          mqtts://192.168.1.100:8883 (TLS)"
  echo "          ws://192.168.1.100:9001/mqtt (WebSocket)"
  MQTT_URL=$(prompt_config "url" "Enter URL")
  if [ -z "$MQTT_URL" ]; then
    echo "Error: URL is required"
    exit 1
  fi
  echo ""

  # Prompt for Topic
  MQTT_TOPIC=$(prompt_config "topic" "Enter MQTT topic (e.g., doorbell/ring)")
  if [ -z "$MQTT_TOPIC" ]; then
    echo "Error: Topic is required"
    exit 1
  fi
  echo ""

  # Prompt for Username
  MQTT_USER=$(prompt_config "username" "Enter MQTT username")
  if [ -z "$MQTT_USER" ]; then
    echo "Error: Username is required"
    exit 1
  fi
  echo ""

  # Prompt for Password
  MQTT_PASS=$(prompt_config "password" "Enter MQTT password" 1)
  if [ -z "$MQTT_PASS" ]; then
    echo "Error: Password is required"
    exit 1
  fi
  echo ""

  # Prompt for Client ID (optional)
  MQTT_CLIENT_ID=$(prompt_config "clientid" "Enter MQTT client ID (optional, press Enter to skip)")
  echo ""

  # Store values in keyring
  echo "Storing configuration in keyring..."

  set_config "url" "$MQTT_URL"
  set_config "topic" "$MQTT_TOPIC"
  set_config "username" "$MQTT_USER"
  set_config "password" "$MQTT_PASS"

  if [ -n "$MQTT_CLIENT_ID" ]; then
    set_config "clientid" "$MQTT_CLIENT_ID"
  fi

  echo ""
  echo "Configuration saved successfully!"
  echo ""
  echo "You can now run the doorbell notifier with:"
  echo "  $0"
  echo ""
  echo "Or view your configuration with:"
  echo "  $0 -v"

  exit 0
}

# Run the doorbell notifier
run_notifier() {
  # Retrieve all configuration from keyring
  MQTT_URL=$(get_config "url")
  MQTT_TOPIC=$(get_config "topic")
  MQTT_USER=$(get_config "username")
  MQTT_PASS=$(get_config "password")
  MQTT_CLIENT_ID=$(get_config "clientid")

  # Verify required values were retrieved
  if [ -z "$MQTT_URL" ] || [ -z "$MQTT_TOPIC" ] || [ -z "$MQTT_USER" ] || [ -z "$MQTT_PASS" ]; then
    logger -t doorbell -p user.error "Failed to retrieve MQTT configuration from keyring"
    {
      echo "Error: Failed to retrieve MQTT configuration from keyring"
      echo ""
      echo "Please run the configuration wizard:"
      echo "  $0 -c"
      echo ""
      echo "Or view current configuration:"
      echo "  $0 -v"
    } >&2
    exit 1
  fi

  # Build mosquitto_sub command with optional client ID
  MOSQUITTO_CMD="mosquitto_sub -L \"${MQTT_URL}\" -t \"${MQTT_TOPIC}\" -u \"${MQTT_USER}\" -P \"${MQTT_PASS}\" -k 60"
  if [ -n "$MQTT_CLIENT_ID" ]; then
    MOSQUITTO_CMD="$MOSQUITTO_CMD -i \"${MQTT_CLIENT_ID}\""
  fi

  logger -t doorbell -p user.info "Starting MQTT doorbell notifier for $MQTT_URL"

  # Main loop: reconnect automatically if connection drops
  while true; do
    logger -t doorbell -p user.info "Connecting to MQTT broker $MQTT_URL"

    # Subscribe to MQTT topic with 60-second keepalive
    # Using -L (URL) format which supports mqtt://, mqtts://, ws://, wss://
    eval $MOSQUITTO_CMD | while read -r message
    do
      # Display notification and play sound
      notify-send "Doorbell" "Someone is at the door!" -u critical -i bell
      canberra-gtk-play -i bell
      logger -t doorbell -p user.notice "Doorbell pressed"
    done

    # If we get here, connection was lost
    logger -t doorbell -p user.warning "MQTT connection to $MQTT_URL lost, reconnecting in 5 seconds"
    sleep 5
  done
}

# Parse command line options
while getopts "cvh" opt; do
  case $opt in
    c)
      configure
      ;;
    v)
      view_config
      exit $?
      ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      {
        echo "Invalid option: -$OPTARG"
        echo ""
        show_help
      } >&2
      exit 1
      ;;
  esac
done

# If no options provided, run the notifier
if [ $OPTIND -eq 1 ]; then
  run_notifier
fi
