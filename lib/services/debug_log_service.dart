import 'dart:async';

/// Service to capture and store debug logs from LoRa device and MQTT
class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final List<LogEntry> _logs = [];
  final _logController = StreamController<LogEntry>.broadcast();
  
  static const int maxLogs = 500; // Keep last 500 log entries

  Stream<LogEntry> get logStream => _logController.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String message, {LogLevel level = LogLevel.info, String? category}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
      category: category,
    );
    
    _logs.add(entry);
    
    // Keep only last maxLogs entries
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    
    _logController.add(entry);
    
    // Also print to console
    print('${entry.level.prefix}[${entry.category ?? 'LOG'}] $message');
  }

  void logLoRa(String message) {
    log(message, level: LogLevel.debug, category: 'LoRa');
  }

  void logPing(String message) {
    log(message, level: LogLevel.success, category: 'PING');
  }

  void logError(String message) {
    log(message, level: LogLevel.error, category: 'ERROR');
  }

  void logInfo(String message) {
    log(message, level: LogLevel.info, category: 'INFO');
  }

  void clear() {
    _logs.clear();
  }

  void dispose() {
    _logController.close();
  }
}

enum LogLevel {
  debug,
  info,
  success,
  warning,
  error;

  String get prefix {
    switch (this) {
      case LogLevel.debug:
        return '🔍 ';
      case LogLevel.info:
        return 'ℹ️  ';
      case LogLevel.success:
        return '✅ ';
      case LogLevel.warning:
        return '⚠️  ';
      case LogLevel.error:
        return '❌ ';
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String? category;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
    this.category,
  });

  String get formattedTime {
    final time = timestamp.toString().substring(11, 19);
    return time;
  }
}
