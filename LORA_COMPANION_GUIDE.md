## MeshCore Wardrive - LoRa Companion Guide

This app now works **exactly like the mesh-map.pages.dev website** - using your LoRa companion device to send actual radio pings and MQTT to listen for observer responses.

## How It Works

```
1. Phone (GPS) → USB/Bluetooth → LoRa Companion
2. LoRa Companion → LoRa Radio → MeshCore Observers
3. Observers → MQTT Broker → App listens
4. Green square = Observer heard you
5. Red square = Dead zone (no observer response)
```

### Key Points

- **LoRa device transmits** the actual radio ping
- **MQTT listens** for responses from observers
- Tests **real mesh coverage**, not just internet connectivity
- Pings every ~0.5 miles (adjustable)
- Can ignore your mobile repeater to avoid false positives

## Setup Steps

### 1. Connect LoRa Companion

**Option A: USB** (Recommended)
1. Plug LoRa device into phone via USB-C/OTG
2. Grant USB permissions when prompted
3. In app: Tap "Scan USB Devices"
4. Select your device from list
5. Wait for "Connected via USB"

**Option B: Bluetooth**
1. Pair LoRa device in Android Bluetooth settings
2. In app: Tap "Scan Bluetooth Devices"
3. Select your device (e.g., "Meshtastic_xxxx")
4. Wait for "Connected via Bluetooth"

### 2. Connect to MQTT

1. Tap "Connect to MQTT"
2. Enter broker details (default: `mqtt.meshcore.io`)
3. Enter credentials if required
4. Wait for "MQTT Connected"

### 3. Configure Settings (Optional)

**Ignore Mobile Repeater:**
- If you carry a portable repeater, set its prefix
- Example: If your repeater ID is `MOB-123`, enter `MOB-`
- This prevents false positive pings

**Ping Interval:**
- Default: Every ~0.5 miles
- Adjust distance filter in settings

### 4. Start Wardriving

1. Enable "Auto-Ping" toggle
2. Tap green play button to start GPS tracking
3. As you move:
   - Every 0.5 miles → LoRa device sends ping
   - Wait 30 seconds for observers to respond via MQTT
   - Green = heard by observer
   - Red = no response (dead zone)

## Supported LoRa Devices

The app should work with:
- **Meshtastic** devices (T-Beam, Heltec, LILYGO, etc.)
- **Custom LoRa** boards with serial interface
- Any device that accepts ping commands via UART

### Command Format

The app sends: `ping {8-char-id}\n`

Example: `ping abc12345\n`

Your LoRa device should:
1. Transmit this as a broadcast LoRa message
2. Include the ping ID in the transmission

## MQTT Configuration

### Default Settings

```
Broker: mqtt.meshcore.io
Port: 1883
Subscribe Topic: meshcore/observer/+/pong
```

### Expected Observer Response Format

When an observer hears your ping, it should publish to MQTT:

**Topic:** `meshcore/observer/{observer_id}/pong`

**Payload:**
```json
{
  "ping_id": "abc12345",
  "observer_id": "OBS-001",
  "rssi": -85,
  "snr": 7,
  "lat": 47.7776,
  "lon": -122.4247,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## Customization

### Change MQTT Broker

Edit `lib/services/lora_companion_service.dart`:

```dart
// Line 69-71
static const String defaultMqttBroker = 'mqtt.meshcore.io';
static const int defaultMqttPort = 1883;
static const String baseTopic = 'meshcore';
```

### Change MQTT Topic Pattern

Edit line 270:
```dart
final topic = '$baseTopic/observer/+/pong';
```

### Adjust Ping Command

Edit line 314:
```dart
await _sendToDevice('ping $pingId\n');
```

For custom LoRa devices, change this to match your command format.

### Change Ping Interval

The app pings based on distance moved. To change:

Edit `lib/services/location_service.dart` line 71:
```dart
distanceFilter: 5, // meters - reduce for more frequent pings
```

For ~0.5 miles: `distanceFilter: 805` (805 meters = 0.5 miles)

## Data Export

Exported samples include all ping data:

```json
{
  "id": "1234567890_c23nb2q2",
  "lat": 47.7776,
  "lon": -122.4247,
  "timestamp": "2024-01-01T12:00:00.000Z",
  "geohash": "c23nb2q2",
  "rssi": -85,
  "snr": 7,
  "pingSuccess": true
}
```

- `pingSuccess: true` = Observer heard your ping (green)
- `pingSuccess: false` = No observer response (red)
- `pingSuccess: null` = Auto-ping was disabled

## Troubleshooting

### LoRa Device Won't Connect

**USB:**
- Check USB-C cable supports data (not just charging)
- Enable USB debugging in Android settings
- Try different USB port

**Bluetooth:**
- Pair device in Android settings first
- Ensure device is in discoverable mode
- Check device battery

### MQTT Won't Connect

- Verify broker address and port
- Check internet connection (cellular/WiFi)
- Confirm credentials if required
- Test broker with MQTT client (MQTT Explorer, mosquitto_sub)

### No Observer Responses

- Verify observers are online and publishing to MQTT
- Check MQTT topic pattern matches
- Ensure LoRa device is actually transmitting
- Confirm ping command format is correct
- Check if you're in range of any observers

### Ping Timeout Too Long

Default timeout is 30 seconds. To reduce:

Edit `lib/services/location_service.dart` line 146:
```dart
timeoutSeconds: 30, // Reduce this value
```

### False Positives from Mobile Repeater

Set ignored repeater prefix in app settings:
- Settings → Ignore Repeater Prefix
- Enter your repeater's ID prefix (e.g., `MOB-`)

## Testing Without Real Network

### Test LoRa Connection

1. Connect device via USB/Bluetooth
2. Check device response in logs
3. Send test ping manually

### Test MQTT Connection

Use a public MQTT broker for testing:
```dart
broker: 'test.mosquitto.org'
port: 1883
// No authentication required
```

### Simulate Observer Response

Use MQTT client to publish test response:

```bash
mosquitto_pub -h mqtt.meshcore.io -t meshcore/observer/TEST/pong -m '{
  "ping_id": "testping",
  "observer_id": "TEST-OBS",
  "rssi": -75,
  "snr": 9
}'
```

## Advanced Features

### Custom Ping Logic

For non-Meshtastic devices, modify `_sendToDevice()` in `lora_companion_service.dart`.

### Custom Response Parsing

Modify `_handleObserverResponse()` (line 383) to match your MQTT response format.

### Add Manual Ping Button

Access `locationService.loraCompanion.ping()` directly for single pings.

## Performance Tips

1. **Ping Interval**: 0.5 miles is good balance - closer intervals may slow you down waiting for responses
2. **Timeout**: 30 seconds is reasonable for mesh networks
3. **Battery**: USB connection drains less battery than Bluetooth
4. **Range**: Stay within observer range for best results

## Security & Privacy

- Your device ID is randomly generated
- GPS coordinates are sent to MQTT broker
- Ping IDs are random 8-character strings
- No personal information transmitted
- All collected data stays local unless exported

## Credits

This implementation replicates the exact workflow from mesh-map.pages.dev for MeshCore coverage mapping with LoRa companions.
