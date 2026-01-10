# MeshCore Wardrive

An Android app for wardriving and mapping MeshCore mesh network coverage. This app replicates the functionality of mesh-map.pages.dev with reliable GPS location tracking on Android devices.

## Features

- **Persistent GPS Tracking**: Continuously tracks your location while wardriving, solving the location tracking issues in mobile browsers
- **Coverage Visualization**: Automatically aggregates GPS samples into coverage areas using geohash
- **Interactive Map**: OpenStreetMap-based map with zoom, pan, and layer controls
- **Color Modes**: 
  - Quality mode: Colors based on sample density
  - Age mode: Colors based on data freshness
- **Data Export**: Export collected samples as JSON for sharing or uploading
- **Local Storage**: All data stored locally using SQLite database
- **Battery Efficient**: Configurable location update intervals

## Installation

### Prerequisites
- Flutter SDK installed
- Android device or emulator
- Android SDK with API level 21 or higher

### Build and Install

```bash
cd meshcore_wardrive
flutter pub get
flutter build apk
flutter install
```

Or to run directly:

```bash
flutter run
```

## Usage

1. **Start Tracking**: Tap the green play button to start GPS tracking
   - The app will request location permissions on first use
   - Grant "Allow all the time" for background tracking

2. **View Coverage**: As you move, the app automatically:
   - Collects GPS samples every 5 meters
   - Aggregates samples into coverage rectangles
   - Colors areas based on signal quality or data age

3. **Map Controls**:
   - Pinch to zoom
   - Drag to pan
   - Tap location button to center on current position
   - Tap settings icon to adjust display options

4. **Export Data**: Tap "Export" to save collected samples as JSON
   - Files are saved to the app's external storage directory
   - Can be uploaded to MeshCore servers or shared

5. **Clear Data**: Tap "Clear" to delete all collected samples

## Settings

Access settings via the gear icon:

- **Show Samples**: Display individual GPS sample points
- **Show Edges**: Display connections between coverage areas and repeaters
- **Color Mode**: Switch between quality and age-based coloring

## Technical Details

### Data Structure

**Sample**: Individual GPS point
- ID: Timestamp + geohash
- Position: Latitude/longitude
- Timestamp: Collection time
- Geohash: 8-character precision geohash

**Coverage**: Aggregated coverage area
- ID: 6-character geohash
- Received count: Number of samples
- Last received: Most recent sample timestamp
- Repeaters: Associated repeater IDs

### Geohash Precision

- **Sample precision**: 8 characters (~19m × 19m)
- **Coverage precision**: 6 characters (~0.61km × 1.22km)

### Location Settings

- Accuracy: High (GPS)
- Distance filter: 5 meters
- Update frequency: Continuous while tracking

## Permissions

The app requires:

- `ACCESS_FINE_LOCATION`: High-accuracy GPS tracking
- `ACCESS_COARSE_LOCATION`: Network-based location
- `ACCESS_BACKGROUND_LOCATION`: Tracking while app is in background
- `INTERNET`: Download map tiles
- `WRITE_EXTERNAL_STORAGE`: Export data files

## Troubleshooting

### Location not updating
- Ensure location services are enabled on your device
- Grant all location permissions to the app
- Check that GPS has a clear view of the sky

### Map not loading
- Check internet connection
- Ensure INTERNET permission is granted

### Export fails
- Grant storage permissions
- Check available storage space

## Project Structure

```
lib/
├── models/          # Data models (Sample, Coverage, Repeater)
├── services/        # Business logic (Location, Database, Aggregation)
├── utils/           # Utilities (Geohash, Distance calculations)
├── screens/         # UI screens (Map screen)
└── main.dart        # App entry point
```

## Credits

Based on the mesh-map.pages.dev web application by Kyle Reed for MeshCore coverage mapping.

## License

MIT License