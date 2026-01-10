import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import '../models/models.dart';

class UploadService {
  static const String _apiUrlKey = 'upload_api_url';
  static const String _autoUploadKey = 'auto_upload_enabled';
  static const String _lastUploadKey = 'last_upload_timestamp';
  
  // Default URL (user can change this)
  static const String defaultApiUrl = 'https://meshwar-map.pages.dev/api/samples';
  
  final DatabaseService _db = DatabaseService();
  
  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? defaultApiUrl;
  }
  
  Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }
  
  Future<bool> isAutoUploadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoUploadKey) ?? false;
  }
  
  Future<void> setAutoUploadEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUploadKey, enabled);
  }
  
  Future<DateTime?> getLastUploadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastUploadKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }
  
  Future<void> _setLastUploadTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUploadKey, time.millisecondsSinceEpoch);
  }
  
  /// Upload all samples to the configured API
  Future<UploadResult> uploadAllSamples() async {
    try {
      final apiUrl = await getApiUrl();
      final samples = await _db.getAllSamples();
      
      if (samples.isEmpty) {
        return UploadResult(success: false, message: 'No samples to upload');
      }
      
      // Convert samples to JSON
      final samplesJson = samples.map((sample) => {
        'nodeId': sample.path ?? 'Unknown', // path contains the repeater/node ID
        'latitude': sample.position.latitude,
        'longitude': sample.position.longitude,
        'rssi': sample.rssi,
        'snr': sample.snr,
        'pingSuccess': sample.pingSuccess,
        'timestamp': sample.timestamp.toIso8601String(),
      }).toList();
      
      // Debug: log first 3 samples
      if (samplesJson.isNotEmpty) {
        print('Uploading ${samplesJson.length} samples');
        print('Sample 1: ${samplesJson.first}');
        if (samplesJson.length > 1) {
          print('Sample 2: ${samplesJson[1]}');
        }
      }
      
      // Send POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'samples': samplesJson}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        await _setLastUploadTime(DateTime.now());
        return UploadResult(
          success: true,
          message: 'Uploaded ${responseData['added']} samples (${responseData['total']} total)',
          uploadedCount: responseData['added'],
          totalCount: responseData['total'],
        );
      } else {
        return UploadResult(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return UploadResult(
        success: false,
        message: 'Upload failed: $e',
      );
    }
  }
  
  /// Upload only samples since last upload
  Future<UploadResult> uploadNewSamples() async {
    try {
      final apiUrl = await getApiUrl();
      final lastUpload = await getLastUploadTime();
      
      final samples = lastUpload != null
          ? await _db.getSamplesSince(lastUpload)
          : await _db.getAllSamples();
      
      if (samples.isEmpty) {
        return UploadResult(success: true, message: 'No new samples to upload');
      }
      
      // Convert samples to JSON
      final samplesJson = samples.map((sample) => {
        'nodeId': sample.path ?? 'Unknown', // path contains the repeater/node ID
        'latitude': sample.position.latitude,
        'longitude': sample.position.longitude,
        'rssi': sample.rssi,
        'snr': sample.snr,
        'pingSuccess': sample.pingSuccess,
        'timestamp': sample.timestamp.toIso8601String(),
      }).toList();
      
      // Send POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'samples': samplesJson}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        await _setLastUploadTime(DateTime.now());
        return UploadResult(
          success: true,
          message: 'Uploaded ${responseData['added']} new samples',
          uploadedCount: responseData['added'],
          totalCount: responseData['total'],
        );
      } else {
        return UploadResult(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return UploadResult(
        success: false,
        message: 'Upload failed: $e',
      );
    }
  }
}

class UploadResult {
  final bool success;
  final String message;
  final int? uploadedCount;
  final int? totalCount;
  
  UploadResult({
    required this.success,
    required this.message,
    this.uploadedCount,
    this.totalCount,
  });
}
