import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Persistent debug logger that writes to a file for troubleshooting Samsung devices
/// This logger survives app kills and restarts
class PersistentDebugLogger {
  static final PersistentDebugLogger _instance = PersistentDebugLogger._internal();
  factory PersistentDebugLogger() => _instance;
  PersistentDebugLogger._internal();

  File? _logFile;
  bool _initialized = false;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  /// Initialize the logger
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Use application support dir (works on iOS and Android); getExternalStorageDirectory is Android-only
      final directory = await getApplicationSupportDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      _logFile = File('${directory.path}/meshcore_debug_$timestamp.txt');

      // Write header
      await _writeToFile('=== MeshCore Wardrive Debug Log ===');
      await _writeToFile('Device: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      await _writeToFile('Started: ${_dateFormat.format(DateTime.now())}');
      await _writeToFile('======================================\n');

      _initialized = true;
      print('Persistent debug logger initialized: ${_logFile!.path}');
    } catch (e) {
      print('Failed to initialize persistent debug logger: $e');
    }
  }

  /// Log a message to the file
  Future<void> log(String category, String message) async {
    if (!_initialized || _logFile == null) {
      await init();
    }

    try {
      final timestamp = _dateFormat.format(DateTime.now());
      await _writeToFile('[$timestamp] [$category] $message');
    } catch (e) {
      print('Failed to write to debug log: $e');
    }
  }

  /// Log service lifecycle events
  Future<void> logServiceEvent(String event) async {
    await log('SERVICE', event);
  }

  /// Log GPS/location events
  Future<void> logLocationEvent(String event) async {
    await log('LOCATION', event);
  }

  /// Log auto-ping events
  Future<void> logPingEvent(String event) async {
    await log('PING', event);
  }

  /// Log permission status
  Future<void> logPermission(String permission, String status) async {
    await log('PERMISSION', '$permission: $status');
  }

  /// Log errors
  Future<void> logError(String context, String error) async {
    await log('ERROR', '$context: $error');
  }

  /// Log battery/power events
  Future<void> logPowerEvent(String event) async {
    await log('POWER', event);
  }

  /// Write to file with proper buffering
  Future<void> _writeToFile(String line) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true, // Force immediate write
      );
    } catch (e) {
      print('Write error: $e');
    }
  }

  /// Get the current log file path
  String? get logFilePath => _logFile?.path;

  /// Close and finalize the log
  Future<void> close() async {
    await _writeToFile('\n=== Log session ended: ${_dateFormat.format(DateTime.now())} ===');
  }
}
