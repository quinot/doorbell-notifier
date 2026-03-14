"""MQTT Doorbell Notifier - main module."""

import argparse
import getpass
import json
import logging

import os
import ssl
import sys
from urllib.parse import urlparse

import emoji
import paho.mqtt.client as mqtt
import yaml

try:
    import gi
    gi.require_version("Notify", "0.7")
    gi.require_version("GSound", "1.0")
    from gi.repository import Notify, GSound
    _GI_AVAILABLE = True
except Exception:
    _GI_AVAILABLE = False


CONFIG_DIR = os.path.join(os.path.expanduser("~"), ".config", "doorbell-notifier")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.yaml")

logger = logging.getLogger("doorbell")

_notify_initialized = False
_gsound_ctx = None


def get_config_path():
    return CONFIG_FILE


def load_config():
    path = get_config_path()
    if not os.path.exists(path):
        sys.exit(f"Error: Config file not found: {path}\nRun 'doorbell-notifier -c' to configure.")

    with open(path) as f:
        data = yaml.safe_load(f)

    if not data:
        sys.exit("Error: Config file is empty. Run 'doorbell-notifier -c' to configure.")

    mqtt_cfg = data.get("mqtt", {})
    for field in ("url", "topic", "username", "password"):
        if not mqtt_cfg.get(field):
            sys.exit(f"Error: Missing required config field: mqtt.{field}")

    return data


def save_config(data):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    path = get_config_path()
    with open(path, "w") as f:
        yaml.safe_dump(data, f, default_flow_style=False, allow_unicode=True)
    os.chmod(path, 0o600)


def configure():
    print("MQTT Doorbell Configuration")
    print("===========================")
    print()

    # Load existing config if present
    path = get_config_path()
    existing = {}
    if os.path.exists(path):
        with open(path) as f:
            existing = yaml.safe_load(f) or {}

    existing_mqtt = existing.get("mqtt", {})

    def prompt(label, key, current, secret=False):
        if current:
            hint = "(hidden)" if secret else current
            display = f"{label} [{hint}]: "
        else:
            display = f"{label}: "
        if secret:
            value = getpass.getpass(display)
        else:
            value = input(display)
        return value if value else current

    url = prompt("MQTT broker URL (e.g. mqtt://host:1883)", "url", existing_mqtt.get("url"))
    if not url:
        sys.exit("Error: URL is required")

    topic = prompt("MQTT topic", "topic", existing_mqtt.get("topic"))
    if not topic:
        sys.exit("Error: Topic is required")

    username = prompt("MQTT username", "username", existing_mqtt.get("username"))
    if not username:
        sys.exit("Error: Username is required")

    password = prompt("MQTT password", "password", existing_mqtt.get("password"), secret=True)
    if not password:
        sys.exit("Error: Password is required")

    client_id = prompt("MQTT client ID (optional)", "client_id", existing_mqtt.get("client_id", ""))

    data = dict(existing)
    data["mqtt"] = {
        "url": url,
        "topic": topic,
        "username": username,
        "password": password,
    }
    if client_id:
        data["mqtt"]["client_id"] = client_id

    # Seed default payload_types if not already present
    if "payload_types" not in data:
        data["payload_types"] = {
            "default": {
                "icon": "bell",
                "sound": "bell",
            },
            "doorbell": {
                "message": "Someone is at the door!",
                "icon": "bell",
                "sound": "bell",
            },
            "motion": {
                "message": "Motion detected!",
                "icon": "camera",
                "sound": "bell",
            },
        }

    save_config(data)
    print()
    print("Configuration saved to", get_config_path())


def view_config():
    config = load_config()
    mqtt_cfg = config.get("mqtt", {})

    print("Current MQTT Doorbell Configuration")
    print("====================================")
    print()
    print(f"URL:       {mqtt_cfg.get('url', '(not set)')}")
    print(f"Topic:     {mqtt_cfg.get('topic', '(not set)')}")
    print(f"Username:  {mqtt_cfg.get('username', '(not set)')}")
    print(f"Password:  {'(hidden)' if mqtt_cfg.get('password') else '(not set)'}")
    if mqtt_cfg.get("client_id"):
        print(f"Client ID: {mqtt_cfg['client_id']}")
    print()

    payload_types = config.get("payload_types", {})
    if payload_types:
        print("Payload types:")
        for ptype, defaults in payload_types.items():
            print(f"  {ptype}: {defaults}")
        print()


def _resolve_icon_or_sound(value):
    """Return (is_file, resolved_value): expand paths, otherwise treat as theme name."""
    if value and (value.startswith("/") or value.startswith("~/") or value.startswith("$HOME/")):
        return True, os.path.expandvars(os.path.expanduser(value))
    return False, value


def _ensure_notify_init():
    global _notify_initialized
    if not _notify_initialized and _GI_AVAILABLE:
        Notify.init("doorbell-notifier")
        _notify_initialized = True


def _get_gsound_ctx():
    global _gsound_ctx
    if _gsound_ctx is None and _GI_AVAILABLE:
        _gsound_ctx = GSound.Context.new()
    return _gsound_ctx


def handle_message(payload_json, config):
    try:
        payload = json.loads(payload_json)
    except json.JSONDecodeError:
        logger.warning("Received non-JSON payload: %s", payload_json)
        return

    msg_type = payload.get("type")
    if not msg_type:
        logger.warning("Payload missing 'type' field: %s", payload_json)
        return

    payload_types = config.get("payload_types", {})
    type_defaults = payload_types.get(msg_type)

    if type_defaults is None:
        type_defaults = payload_types.get("default", {})
        logger.warning("Unknown payload type '%s', using default", msg_type)

    # Merge: config defaults, then payload overrides (excluding 'type')
    merged = dict(type_defaults)
    for k, v in payload.items():
        if k != "type":
            merged[k] = v

    message = emoji.emojize(merged.get("message", msg_type), language="alias")
    icon = merged.get("icon")
    sound = merged.get("sound")

    logger.info("Doorbell event: type=%s message=%s", msg_type, message)

    if _GI_AVAILABLE:
        _ensure_notify_init()

        # Desktop notification
        icon_is_file, icon_resolved = _resolve_icon_or_sound(icon) if icon else (False, None)
        n = Notify.Notification.new("Doorbell", message, icon_resolved)
        n.set_urgency(Notify.Urgency.CRITICAL)
        try:
            n.show()
        except Exception:
            # Notification daemon may have restarted; reinitialise and retry once
            global _notify_initialized
            _notify_initialized = False
            _ensure_notify_init()
            n.show()

        # Sound
        if sound:
            ctx = _get_gsound_ctx()
            if ctx:
                sound_is_file, sound_resolved = _resolve_icon_or_sound(sound)
                try:
                    if sound_is_file:
                        ctx.play_simple({GSound.ATTR_MEDIA_FILENAME: sound_resolved}, None)
                    else:
                        ctx.play_simple({GSound.ATTR_EVENT_ID: sound_resolved}, None)
                except Exception as e:
                    logger.warning("Failed to play sound %r: %s", sound_resolved, e)
    else:
        logger.warning("GObject introspection not available; skipping notification display")


def run_notifier():
    config = load_config()
    mqtt_cfg = config["mqtt"]

    url = mqtt_cfg["url"]
    parsed = urlparse(url)
    scheme = parsed.scheme  # mqtt, mqtts, ws, wss
    host = parsed.hostname
    port = parsed.port or (8883 if scheme in ("mqtts", "wss") else 1883)
    topic = mqtt_cfg["topic"]

    use_tls = scheme in ("mqtts", "wss")
    use_ws = scheme in ("ws", "wss")

    transport = "websockets" if use_ws else "tcp"

    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=mqtt_cfg.get("client_id", ""),
        transport=transport,
    )
    client.username_pw_set(mqtt_cfg["username"], mqtt_cfg["password"])

    if use_tls:
        client.tls_set(cert_reqs=ssl.CERT_REQUIRED)

    client.reconnect_delay_set(min_delay=5, max_delay=60)

    def on_connect(client, userdata, flags, reason_code, properties):
        if reason_code == 0:
            logger.info("Connected to MQTT broker %s", url)
            client.subscribe(topic)
        else:
            logger.error("Failed to connect to MQTT broker: reason_code=%s", reason_code)

    def on_disconnect(client, userdata, disconnect_flags, reason_code, properties):
        if reason_code != 0:
            logger.warning("Disconnected from MQTT broker (reason_code=%s), will reconnect", reason_code)
        else:
            logger.info("Disconnected from MQTT broker")

    def on_message(client, userdata, msg):
        payload = msg.payload.decode("utf-8", errors="replace")
        handle_message(payload, config)

    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message

    logger.info("Starting doorbell notifier, connecting to %s", url)

    if use_ws and parsed.path:
        client.ws_set_options(path=parsed.path)

    client.connect(host, port, keepalive=60)
    client.loop_forever()


def main():
    parser = argparse.ArgumentParser(
        prog="doorbell-notifier",
        description="MQTT doorbell desktop notifier",
    )
    parser.add_argument("-c", "--configure", action="store_true", help="Configure MQTT settings interactively")
    parser.add_argument("-v", "--view-config", action="store_true", dest="view", help="View current configuration")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s %(message)s",
    )

    if args.configure:
        configure()
    elif args.view:
        view_config()
    else:
        run_notifier()


if __name__ == "__main__":
    main()
