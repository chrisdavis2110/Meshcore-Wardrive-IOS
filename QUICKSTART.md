# MeshCore Wardrive - Quick Start

## Build and Install

The app has been successfully built! You can install it on your Android device.

### Install on Connected Device

```bash
cd /home/chuck/Desktop/meshcore_wardrive
flutter install
```

### Or Install APK Manually

The APK is located at:
```
/home/chuck/Desktop/meshcore_wardrive/build/app/outputs/flutter-apk/app-debug.apk
```

Transfer this file to your Android device and install it.

## First Launch

1. **Grant Permissions**: When you first open the app, grant:
   - Location permissions (choose "Allow all the time" for best results)
   - Storage permissions (for exporting data)

2. **Start Tracking**: Tap the green play button (bottom right)
   - The button will turn red when tracking is active
   - Your position will update automatically every 5 meters

3. **View Your Coverage**: As you move:
   - GPS samples are collected automatically
   - Coverage areas appear as colored rectangles
   - Colors indicate signal quality (default) or data age

## Key Features

### Map Controls
- **My Location Button** (small blue button): Centers map on your current position
- **Start/Stop Button** (large green/red): Toggles location tracking
- **Settings Icon** (top right): Access display options

### Settings Options
- **Show Samples**: Toggle individual GPS point visibility
- **Show Edges**: Toggle repeater connection lines
- **Color Mode**:
  - Quality: Green (excellent) → Red (poor)
  - Age: Green (fresh) → Red (old)

### Data Management
- **Export**: Saves all collected samples as JSON file
  - Files saved to app's external storage
  - Named with timestamp: `meshcore_export_YYYYMMDD_HHMMSS.json`
  
- **Clear**: Deletes all collected data (with confirmation)

## Tips for Wardriving

1. **Battery Optimization**: Disable battery optimization for this app in Android settings
2. **Keep GPS Clear**: Ensure device has clear view of sky for best accuracy
3. **Regular Exports**: Export data periodically to avoid data loss
4. **Background Tracking**: The app can track in the background on Android 10+

## Data Format

Exported JSON contains an array of samples:
```json
[
  {
    "id": "timestamp_geohash",
    "lat": 47.7776,
    "lon": -122.4247,
    "timestamp": "2024-01-01T12:00:00.000Z",
    "path": null,
    "geohash": "c23nb2q2"
  }
]
```

## Troubleshooting

### Location Not Updating
- Check Location Services are enabled
- Grant "Allow all the time" permission
- Restart the app

### Map Not Loading
- Check internet connection (needed for map tiles)
- Verify INTERNET permission is granted

### Export Fails
- Grant storage permissions
- Check available storage space

## Technical Details

- **Sample Rate**: Every 5 meters of movement
- **Location Accuracy**: High (GPS)
- **Coverage Precision**: ~0.61km × 1.22km grid
- **Sample Precision**: ~19m × 19m grid
- **Center Point**: 47.7776, -122.4247 (Puget Sound area)
- **Max Distance**: 60 miles from center

## Development

To make changes:

1. Edit source files in `lib/`
2. Run `flutter pub get` if you add dependencies
3. Test with `flutter run`
4. Build release with `flutter build apk --release`

## Credits

Based on mesh-map.pages.dev by Kyle Reed for MeshCore network coverage mapping.
