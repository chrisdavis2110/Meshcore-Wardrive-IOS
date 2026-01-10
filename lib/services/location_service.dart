import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import '../utils/geohash_utils.dart';
import 'database_service.dart';
import 'lora_companion_service.dart';

class LocationService {
  final DatabaseService _dbService = DatabaseService();
  final LoRaCompanionService _loraCompanion = LoRaCompanionService();
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  bool _autoPingEnabled = false;
  double _pingIntervalMeters = 805.0; // Default 0.5 miles
  LatLng? _lastPingPosition;
  
  // Stream for broadcasting current position
  final _currentPositionController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get currentPositionStream => _currentPositionController.stream;
  
  // Stream for broadcasting when samples are saved
  final _sampleSavedController = StreamController<void>.broadcast();
  Stream<void> get sampleSavedStream => _sampleSavedController.stream;
  
  // Stream for broadcasting ping events
  final _pingEventController = StreamController<String>.broadcast();
  Stream<String> get pingEventStream => _pingEventController.stream;

  /// Check if location permissions are granted
  Future<bool> checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current position once
  Future<LatLng?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) return null;

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Initialize foreground service
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'meshcore_wardrive_location',
        channelName: 'MeshCore Wardrive Location Tracking',
        channelDescription: 'This notification appears when location tracking is active',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // Update every 5 seconds
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Start tracking location
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    final hasPermission = await checkPermissions();
    if (!hasPermission) return false;

    final isEnabled = await isLocationServiceEnabled();
    if (!isEnabled) return false;

    // Request notification permission for Android 13+
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      print('Notification permission denied - foreground service may not work properly');
    }

    try {
      // Initialize and start foreground service
      _initForegroundTask();
      
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'MeshCore Wardrive',
        notificationText: 'Location tracking active',
        notificationButtons: [
          const NotificationButton(id: 'stop', text: 'Stop Tracking'),
        ],
        callback: null, // We handle location in Flutter, not in service callback
      );
      
      print('Foreground service started');
      
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handleNewPosition(position);
        },
        onError: (error) {
          print('Location stream error: $error');
        },
      );

      // Enable wakelock to prevent screen from sleeping and stopping tracking
      await WakelockPlus.enable();
      print('Wakelock enabled - app will stay active during tracking');

      _isTracking = true;
      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      return false;
    }
  }

  /// Get LoRa companion service
  LoRaCompanionService get loraCompanion => _loraCompanion;

  /// Enable auto-ping (requires LoRa device to be connected)
  void enableAutoPing() {
    if (_loraCompanion.isDeviceConnected) {
      _autoPingEnabled = true;
    }
  }

  /// Disable auto-ping
  void disableAutoPing() {
    _autoPingEnabled = false;
  }

  /// Check if auto-ping is enabled
  bool get isAutoPingEnabled => _autoPingEnabled;

  /// Check if ready for auto-ping
  bool get isReadyForAutoPing => 
      _loraCompanion.isDeviceConnected;
  
  /// Set ping interval in meters
  void setPingInterval(double meters) {
    _pingIntervalMeters = meters;
  }
  
  /// Get current ping interval in meters
  double get pingIntervalMeters => _pingIntervalMeters;

  /// Handle new position from location stream
  void _handleNewPosition(Position position) async {
    final latLng = LatLng(position.latitude, position.longitude);
    
    // Broadcast current position to listeners
    _currentPositionController.add(latLng);

    // Validate location
    if (!GeohashUtils.isValidLocation(latLng)) {
      print('Location outside valid range: $latLng');
      return;
    }

    // Create sample
    final geohash = GeohashUtils.sampleKey(
      position.latitude,
      position.longitude,
    );

    // Check if we should trigger a ping (but don't wait for it)
    if (_autoPingEnabled && _loraCompanion.isDeviceConnected) {
      bool shouldPing = false;
      
      if (_lastPingPosition == null) {
        // First ping
        shouldPing = true;
      } else {
        // Calculate distance from last ping
        final distance = Geolocator.distanceBetween(
          _lastPingPosition!.latitude,
          _lastPingPosition!.longitude,
          latLng.latitude,
          latLng.longitude,
        );
        
        if (distance >= _pingIntervalMeters) {
          shouldPing = true;
        }
      }
      
      if (shouldPing) {
        // Update last ping position immediately to prevent multiple pings
        _lastPingPosition = latLng;
        
        // Notify UI that ping is starting
        _pingEventController.add('pinging');
        
        // Update foreground notification
        FlutterForegroundTask.updateService(
          notificationTitle: 'MeshCore Wardrive',
          notificationText: 'Pinging...',
        );
        
        // Start ping in background - don't wait for it
        print('Triggering auto-ping via LoRa at ${latLng.latitude}, ${latLng.longitude}');
        _performPingInBackground(latLng, geohash);
        return; // Don't save GPS sample when auto-pinging - wait for ping result
      }
    }

    // Only save GPS sample if auto-ping is disabled or no ping triggered
    final sample = Sample(
      id: '${DateTime.now().millisecondsSinceEpoch}_$geohash',
      position: latLng,
      timestamp: DateTime.now(),
      path: null,
      geohash: geohash,
      rssi: null,
      snr: null,
      pingSuccess: null, // GPS-only sample (no ping attempted)
    );

    // Save to database
    try {
      await _dbService.insertSample(sample);
      print('Saved GPS sample: ${sample.id} at ${latLng.latitude}, ${latLng.longitude}');
      // Notify listeners that a sample was saved
      _sampleSavedController.add(null);
    } catch (e) {
      print('Error saving sample: $e');
    }
  }
  
  /// Perform ping in background and update sample when complete
  void _performPingInBackground(LatLng latLng, String geohash) async {
    try {
      final pingResult = await _loraCompanion.ping(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        timeoutSeconds: 20,
      );
      
      final pingSuccess = pingResult.status == PingStatus.success;
      final nodeId = pingResult.nodeId;
      
      print('Ping complete: ${pingResult.status.name}, Node: $nodeId, RSSI: ${pingResult.rssi}, SNR: ${pingResult.snr}');
      
      // Update notification with result
      final resultText = pingSuccess ? '✅ Heard by ${nodeId ?? "repeater"}' : '❌ No response';
      FlutterForegroundTask.updateService(
        notificationTitle: 'MeshCore Wardrive',
        notificationText: resultText,
      );
      
      // Notify UI
      _pingEventController.add(pingSuccess ? 'success' : 'failed');
      
      // Reset notification after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        FlutterForegroundTask.updateService(
          notificationTitle: 'MeshCore Wardrive',
          notificationText: 'Location tracking active',
        );
      });
      
      // Create a new sample with ping results
      final sample = Sample(
        id: '${DateTime.now().millisecondsSinceEpoch}_$geohash',
        position: latLng,
        timestamp: DateTime.now(),
        path: nodeId,
        geohash: geohash,
        rssi: pingResult.rssi,
        snr: pingResult.snr,
        pingSuccess: pingSuccess,
      );
      
      // Save ping result as new sample
      await _dbService.insertSample(sample);
      print('Saved ping result: ${sample.id}');
      // Notify listeners
      _sampleSavedController.add(null);
    } catch (e) {
      print('Error during background ping: $e');
      // Save failed ping result
      final sample = Sample(
        id: '${DateTime.now().millisecondsSinceEpoch}_$geohash',
        position: latLng,
        timestamp: DateTime.now(),
        path: null,
        geohash: geohash,
        rssi: null,
        snr: null,
        pingSuccess: false,
      );
      await _dbService.insertSample(sample);
      // Notify listeners
      _sampleSavedController.add(null);
    }
  }

  /// Stop tracking location
  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    // Stop foreground service
    await FlutterForegroundTask.stopService();
    
    // Disable wakelock when tracking stops
    await WakelockPlus.disable();
    print('Wakelock disabled');
    
    _isTracking = false;
  }

  /// Check if currently tracking
  bool get isTracking => _isTracking;

  /// Get all recorded samples
  Future<List<Sample>> getAllSamples() async {
    return await _dbService.getAllSamples();
  }

  /// Get sample count
  Future<int> getSampleCount() async {
    return await _dbService.getSampleCount();
  }

  /// Clear all samples
  Future<void> clearAllSamples() async {
    await _dbService.deleteAllSamples();
  }

  /// Export samples as JSON
  Future<List<Map<String, dynamic>>> exportSamples() async {
    return await _dbService.exportSamples();
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _currentPositionController.close();
    _sampleSavedController.close();
    _pingEventController.close();
    _loraCompanion.dispose();
  }
}
