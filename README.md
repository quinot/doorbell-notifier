# MQTT Doorbell Notifier

A desktop notification service that listens to MQTT topics and displays notifications when doorbell events are received. Perfect for integrating smart doorbells with your Linux desktop.

## Features

- Desktop notifications with visual and audio alerts
- Structured JSON message format with per-type defaults
- Automatic reconnection on connection loss
- System logging for troubleshooting
- Interactive configuration wizard
- Configuration stored in `~/.config/doorbell-notifier/config.yaml`
- Runs as a user systemd service

## Requirements

- Linux system with GNOME, MATE, or similar desktop environment
- Home Assistant (or any MQTT broker)
- Zigbee smart button (or any MQTT-capable doorbell)
- Python 3.9+, pipx

## Dependencies

Install system packages:
```bash
sudo apt install pipx python3-gi gir1.2-notify-0.7 gir1.2-gsound-1.0
```

**Package details:**
- `pipx` - Isolated Python application installer
- `python3-gi` - Python GObject introspection bindings
- `gir1.2-notify-0.7` - Desktop notification support (libnotify)
- `gir1.2-gsound-1.0` - Desktop event sound support (GSound/libcanberra)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/quinot/doorbell-notifier.git
cd doorbell-notifier
```

2. Run the installer:
```bash
./install.sh
```

The installer will:
- Check for required dependencies
- Install the application via `pipx` to `~/.local/bin/`
- Install the systemd service to `~/.config/systemd/user/`
- Provide instructions for the next steps

## Configuration

Configure your MQTT connection settings:
```bash
doorbell-notifier -c
```

You'll be prompted for:
- **MQTT Broker URL**: e.g., `mqtt://192.168.1.100:1883`
  - Supports: `mqtt://`, `mqtts://` (TLS), `ws://` (WebSocket), `wss://` (secure WebSocket)
- **MQTT Topic**: e.g., `doorbell/ring`
- **Username**: Your MQTT username
- **Password**: Your MQTT password (hidden input)
- **Client ID**: Optional unique identifier

Pressing Enter at any prompt keeps the existing value. Configuration is saved to `~/.config/doorbell-notifier/config.yaml` (chmod 600).

The first run of `-c` also seeds a default `payload_types` section in the config (see [Message Format](#message-format) below).

### View Configuration
```bash
doorbell-notifier -v
```

### Edit Configuration

Re-run the configuration wizard (existing values are shown as defaults):
```bash
doorbell-notifier -c
```

### Config file

The full config file format:

```yaml
mqtt:
  url: mqtt://192.168.1.100:1883
  topic: doorbell/ring
  username: user
  password: secret
  client_id: doorbell-notifier  # optional

payload_types:
  default:          # fallback for unknown types
    icon: bell
    sound: bell
  doorbell:
    message: "Someone is at the door!"
    icon: bell
    sound: bell
  motion:
    message: "Motion detected!"
    icon: camera
    sound: bell
```

Icons and sounds can be specified as:
- A system theme name/ID (e.g. `bell`, `message-new-instant`) — passed directly to libnotify/libcanberra
- An absolute or home-relative file path (e.g. `/usr/share/sounds/freedesktop/stereo/bell.oga`, `~/sounds/custom.oga`) — expanded and used as a file

> **Note:** libcanberra supports OGG Vorbis (`.oga`, `.ogg`) and WAV (`.wav`) sound files. MP3 files are not supported; convert them first with e.g. `ffmpeg -i input.mp3 output.oga`.

## Message Format

The notifier expects JSON payloads on the configured MQTT topic.

### Minimal message

```json
{"type": "doorbell"}
```

The `type` field is looked up in `payload_types` in the config. All fields from the matching entry (`message`, `icon`, `sound`) are used as defaults.

### Override individual fields

Any field from the config defaults can be overridden in the payload:

```json
{"type": "doorbell", "message": "Package delivered!"}
{"type": "motion", "icon": "camera-photo", "sound": "/home/user/sounds/alert.oga"}
```

Payload fields take precedence over config defaults; the `type` field itself is never passed through.

### Unknown type

If `type` is not found in `payload_types`, the `default` entry is used as the base (if defined), and a warning is logged. `message` defaults to the type name if not provided by the payload or the default entry.

### Field reference

| Field | Description |
|-------|-------------|
| `type` | **Required.** Matches a key in `payload_types`. |
| `message` | Notification body text. |
| `icon` | Theme icon name or file path. |
| `sound` | Theme sound ID or file path. |

## Usage

### Enable and Start the Service

Enable the service to start automatically on login:
```bash
systemctl --user enable doorbell-notifier.service
systemctl --user start doorbell-notifier.service
```

### Check Service Status
```bash
systemctl --user status doorbell-notifier.service
```

### View Logs
```bash
# View all logs
journalctl --user -u doorbell-notifier.service

# Follow logs in real-time
journalctl --user -u doorbell-notifier.service -f

# View logs from today
journalctl --user -u doorbell-notifier.service --since today
```

### Stop the Service
```bash
systemctl --user stop doorbell-notifier.service
```

### Disable Autostart
```bash
systemctl --user disable doorbell-notifier.service
```

## Home Assistant Setup

1. **Create an automation** in Home Assistant (Settings → Automations & Scenes)

2. **Set the trigger** to your Zigbee button press event

3. **Set the action** to publish to MQTT:
   - Service: `mqtt.publish`
   - Topic: `doorbell/ring` (or whatever you configured)
   - Payload: `{"type": "doorbell"}`

Example automation YAML:
```yaml
alias: Doorbell MQTT Notify
trigger:
  - platform: device
    device_id: your_button_device_id
    domain: mqtt
    type: action
    subtype: single
action:
  - service: mqtt.publish
    data:
      topic: doorbell/ring
      payload: '{"type": "doorbell"}'
```

To include a custom message:
```yaml
      payload: '{"type": "doorbell", "message": "Someone at the front door"}'
```

## Testing

Test your setup by publishing a message manually:
```bash
mosquitto_pub -h YOUR_MQTT_BROKER -t doorbell/ring \
  -m '{"type": "doorbell"}' -u USERNAME -P PASSWORD
```

You should see a notification and hear a bell sound.

## Troubleshooting

### Notifications not appearing

1. Test notifications manually:
```bash
python3 -c "
import gi; gi.require_version('Notify','0.7')
from gi.repository import Notify
Notify.init('test')
n = Notify.Notification.new('Test', 'Notification works', 'bell')
n.show()
"
```

2. If notifications don't work, ensure a notification daemon is running:
```bash
sudo apt install mate-notification-daemon
mate-notification-daemon &
```

### No sound playing

1. Test sound playback:
```bash
python3 -c "
import gi; gi.require_version('GSound','1.0')
from gi.repository import GSound
ctx = GSound.Context.new()
ctx.play_simple({GSound.ATTR_EVENT_ID: 'bell'}, None)
"
```

2. If no sound, install the freedesktop sound theme:
```bash
sudo apt install sound-theme-freedesktop
```

### Service won't start

1. Check service status and logs:
```bash
systemctl --user status doorbell-notifier.service
journalctl --user -u doorbell-notifier.service -n 50
```

2. Verify configuration:
```bash
doorbell-notifier -v
```

3. Test manually:
```bash
doorbell-notifier
```

### Connection issues

1. Verify MQTT broker is accessible:
```bash
mosquitto_sub -h YOUR_BROKER -t test/topic -u USERNAME -P PASSWORD -v
```

2. Check the logs for connection errors:
```bash
journalctl --user -u doorbell-notifier.service -f
```

## Uninstallation
```bash
./uninstall.sh
```

This will:
- Stop and disable the service
- Remove the service file
- Uninstall the application via `pipx`
- **Note:** The configuration file is NOT removed

To also remove the configuration:
```bash
rm -rf ~/.config/doorbell-notifier
```

## Security Notes

- Credentials are stored in `~/.config/doorbell-notifier/config.yaml` with permissions 600 (readable only by your user)
- The service runs with your user permissions, not as root

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

Copyright (c) 2026 Thomas Quinot

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Author

Thomas Quinot - [@quinot](https://github.com/quinot)

## Support

For issues and questions, please open an issue on GitHub.
