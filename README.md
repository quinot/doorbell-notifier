# MQTT Doorbell Notifier

A desktop notification service that listens to MQTT topics and displays notifications when doorbell events are received. Perfect for integrating smart doorbells with your Linux desktop.

## Features

- 🔔 Desktop notifications with visual and audio alerts
- 🔐 Secure credential storage using system keyring
- 🔄 Automatic reconnection on connection loss
- 📝 System logging for troubleshooting
- ⚙️ Interactive configuration wizard
- 🚀 Runs as a user systemd service

## Requirements

- Linux system with MATE, GNOME, or similar desktop environment
- Home Assistant (or any MQTT broker)
- Zigbee smart button (or any MQTT-capable doorbell)

## Dependencies

The following packages are required:
```bash
sudo apt install mosquitto-clients libsecret-tools gnome-session-canberra libnotify-bin
```

**Package details:**
- `mosquitto-clients` - MQTT client tools
- `libsecret-tools` - Keyring access for secure credential storage
- `gnome-session-canberra` - System sound support
- `libnotify-bin` - Desktop notification support

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
- Install the script to `~/.local/bin/`
- Install the systemd service to `~/.config/systemd/user/`
- Provide instructions for the next steps

## Configuration

Configure your MQTT connection settings:
```bash
doorbell-notifier.sh -c
```

You'll be prompted for:
- **MQTT Broker URL**: e.g., `mqtt://192.168.1.100:1883`
  - Supports: `mqtt://`, `mqtts://` (TLS), `ws://` (WebSocket), `wss://` (secure WebSocket)
- **MQTT Topic**: e.g., `doorbell/ring`
- **Username**: Your MQTT username
- **Password**: Your MQTT password (hidden input)
- **Client ID**: Optional unique identifier

Configuration is securely stored in your system keyring and can be viewed/edited later.

### View Configuration
```bash
doorbell-notifier.sh -v
```

### Edit Configuration

Simply run the configuration wizard again:
```bash
doorbell-notifier.sh -c
```

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

1. **Create an automation** in Home Assistant (Settings → Automations & Scenes):

2. **Set the trigger** to your Zigbee button press event

3. **Set the action** to publish to MQTT:
   - Service: `mqtt.publish`
   - Topic: `doorbell/ring` (or whatever you configured)
   - Payload: `pressed`

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
      payload: "pressed"
```

## Testing

Test your setup by publishing a message manually:
```bash
mosquitto_pub -h YOUR_MQTT_BROKER -t doorbell/ring -m "test" -u USERNAME -P PASSWORD
```

You should see a notification and hear a bell sound.

## Customization

### Change Notification Icon

Edit the script and modify the `notify-send` line:
```bash
notify-send "Doorbell" "Someone is at the door!" -u critical -i bell
```

Available icons can be browsed with `gtk3-icon-browser` (install with `sudo apt install gtk-3-examples`).

### Change Notification Sound

Edit the script and modify the `canberra-gtk-play` line:
```bash
canberra-gtk-play -i bell
```

Available sounds:
- `bell` - Classic bell
- `alarm-clock-elapsed` - Alarm sound
- `message-new-instant` - Message notification
- Or use `paplay /path/to/custom/sound.oga`

### Change Notification Text

Edit the notification message in the script:
```bash
notify-send "Custom Title" "Custom message!" -u critical -i bell
```

## Troubleshooting

### Notifications not appearing

1. Check if the notification daemon is running:
```bash
ps aux | grep mate-notification-daemon
```

2. Test notifications manually:
```bash
notify-send "Test" "This is a test"
```

3. If notifications don't work, install/start the notification daemon:
```bash
sudo apt install mate-notification-daemon
mate-notification-daemon &
```

### No sound playing

1. Test sound playback:
```bash
canberra-gtk-play -i bell
```

2. If no sound, install sound theme:
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
doorbell-notifier.sh -v
```

3. Test the script manually:
```bash
doorbell-notifier.sh
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

### Keyring/secret-tool errors

If running from a non-graphical session, the keyring might not be unlocked. The service is designed to run as a user service during an active desktop session.

## Uninstallation
```bash
./uninstall.sh
```

This will:
- Stop and disable the service
- Remove the script and service files
- **Note:** Configuration stored in the keyring is NOT removed

To manually remove keyring configuration:
```bash
secret-tool clear service mqtt field url
secret-tool clear service mqtt field topic
secret-tool clear service mqtt field username
secret-tool clear service mqtt field password
secret-tool clear service mqtt field clientid
```

Or use the GUI: Open "Passwords and Keys" (Seahorse) and delete the MQTT Doorbell entries.

## Security Notes

- Credentials are stored securely in the system keyring (GNOME Keyring)
- The keyring is encrypted and unlocked when you log in
- Only your user account can access the stored credentials
- The service runs with your user permissions, not as root

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Uses [Eclipse Mosquitto](https://mosquitto.org/) MQTT clients
- Integrates with [Home Assistant](https://www.home-assistant.io/)
- Uses [GNOME Keyring](https://wiki.gnome.org/Projects/GnomeKeyring) for secure storage

## Author

Thomas Quinot - [@quinot](https://github.com/quinot)

## Support

For issues and questions, please open an issue on GitHub.
```

## LICENSE
```
MIT License

Copyright (c) 2026 Your Name

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
