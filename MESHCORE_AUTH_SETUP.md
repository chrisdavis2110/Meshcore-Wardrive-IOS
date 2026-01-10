# MeshCore Authentication Setup

The app now supports MeshCore's Ed25519 signature-based authentication for MQTT.

## What You Need

### 1. Your MeshCore Keys

You need two keys from your MeshCore device:

**Public Key** (64 hex characters, 32 bytes):
- Example: `7E7662676F7F0850A8A355BAAFBFC1EB7B4174C340442D7D7161C9474A2C9400`
- This identifies your device

**Private Key** (128 hex characters, 64 bytes):
- Used to sign authentication tokens
- Keep this secret!

### 2. MQTT Broker Address

Based on the GitHub repo, likely:
- `mqtt.letsme.sh` (port 8883 for WebSocket)
- Or check with your MeshCore administrator

### 3. IATA Code

Your geographical area code (3 letters):
- `SEA` - Seattle
- `PDX` - Portland  
- `BOS` - Boston
- `test` - For testing

## How to Get Your Keys

### From Your LoRa Device

If you're using Meshtastic or similar:

1. Connect device via USB/Serial
2. Use Meshtastic CLI or app to export keys
3. Look for "Node Key" or "Private Key"

### From MeshCore Configuration

Check your device's configuration files or setup documentation.

## Authentication Flow

1. **Username**: `v1_{YOUR_PUBLIC_KEY_UPPERCASE}`
   - Example: `v1_7E7662676F7F0850A8A355BAAFBFC1EB7B4174C340442D7D7161C9474A2C9400`

2. **Password**: JWT token signed with your private key
   - Format: `header.payload.signature`
   - Signature uses Ed25519
   - Token includes:
     - `publicKey`: Your public key
     - `aud`: Broker domain (e.g., "mqtt.letsme.sh")
     - `iat`: Current timestamp
     - `exp`: Expiration (optional, e.g., 24 hours)

3. **Topics**:
   - **Publish to**: `meshcore/{IATA}/{YOUR_PUBLIC_KEY}/packets`
   - **Subscribe to**: `meshcore/#` (all messages)
   - **Observer responses**: `meshcore/{IATA}/{OBSERVER_KEY}/packets`

## Using in the App

### 1. Connect to MQTT

When you tap "Connect MQTT", you'll need to enter:

- **Broker**: `mqtt.letsme.sh` (or your broker)
- **Port**: `8883` (WebSocket)
- **Public Key**: Your 64-char hex key
- **Private Key**: Your 128-char hex key  
- **IATA Code**: Your area code (e.g., `SEA`)

The app will:
1. Generate authentication token using Ed25519
2. Create username: `v1_{PUBLIC_KEY}`
3. Connect via WebSocket MQTT
4. Subscribe to `meshcore/#`

### 2. Publishing Pings

When you ping, the app will:
1. Send ping command to your LoRa device
2. Your device transmits over LoRa radio
3. Observers hear it and publish to MQTT
4. Format: `meshcore/{OBSERVER_IATA}/{OBSERVER_KEY}/packets`

### 3. Listening for Responses

The app subscribes to all MeshCore messages and:
1. Filters for messages containing your ping ID
2. Extracts RSSI, SNR, and observer info
3. Marks location as green (covered) or red (dead zone)

## Topic Structure Example

**Your pings** (if published to MQTT):
```
meshcore/SEA/7E7662...9400/packets
```

**Observer responses**:
```
meshcore/SEA/8F8773...AB00/packets
```

**Message payload** (JSON):
```json
{
  "type": "pong",
  "ping_id": "abc12345",
  "rssi": -85,
  "snr": 7,
  "observer_id": "8F8773...AB00"
}
```

## Security Notes

- Your **private key is stored only on your phone** - never sent to servers
- Tokens are signed locally using Ed25519
- Each token includes an expiration for security
- The broker validates signatures using your public key

## Troubleshooting

### "Authentication Failed"

- Check your public/private keys are correct
- Verify they're 64 and 128 hex characters
- Ensure audience matches broker domain
- Check keys are uppercase in username

### "Connection Refused"

- Verify broker address and port
- Check WebSocket port (usually 8883)
- Ensure you have internet connection

### "No Observer Responses"

- Verify observers are publishing to MQTT
- Check your IATA code matches observer area
- Ensure your LoRa device is transmitting
- Check observer topic format

## Testing Without Real Network

You can test authentication using a monitor account:

```dart
// Create test token
final token = MeshCoreAuth.createAuthToken(
  publicKey: 'YOUR_PUBLIC_KEY',
  privateKey: 'YOUR_PRIVATE_KEY',
  audience: 'mqtt.letsme.sh',
  expirationSeconds: 86400,
);

// Username: v1_YOUR_PUBLIC_KEY
// Password: (the token above)
```

Connect with MQTT.fx or another client to verify authentication works.

## Next Steps

1. Get your MeshCore keys from your device
2. Find your MQTT broker address
3. Enter credentials in the app's "Connect MQTT" dialog
4. Test connection before wardriving

## Reference

- [MeshCore MQTT Broker](https://github.com/michaelhart/meshcore-mqtt-broker)
- [Ed25519 Signatures](https://ed25519.cr.yp.to/)
