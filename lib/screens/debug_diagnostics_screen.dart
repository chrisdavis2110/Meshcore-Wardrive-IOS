import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/location_service.dart';
import 'package:path_provider/path_provider.dart';

/// Debug diagnostics screen for troubleshooting Samsung device issues
class DebugDiagnosticsScreen extends StatefulWidget {
  final LocationService locationService;

  const DebugDiagnosticsScreen({
    super.key,
    required this.locationService,
  });

  @override
  State<DebugDiagnosticsScreen> createState() => _DebugDiagnosticsScreenState();
}

class _DebugDiagnosticsScreenState extends State<DebugDiagnosticsScreen> {
  List<File> _logFiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _loading = true);

    try {
      // Same directory as PersistentDebugLogger (application support; works on iOS and Android)
      final directory = await getApplicationSupportDirectory();
      final files = directory.listSync()
          .whereType<File>()
          .where((file) => file.path.contains('meshcore_debug_'))
          .toList();
      // Sort by date (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      setState(() {
        _logFiles = files;
        _loading = false;
      });
    } catch (e) {
      print('Error loading log files: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _shareLogFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MeshCore Wardrive Debug Log',
        text: 'Debug log for troubleshooting GPS and auto-ping issues',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Future<void> _deleteLogFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this log file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        await _loadLogFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log file deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting file: $e')),
          );
        }
      }
    }
  }

  Future<void> _viewLogFile(File file) async {
    try {
      final content = await file.readAsString();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _LogViewerScreen(
              fileName: file.path.split('/').last,
              content: content,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Troubleshooting Samsung Devices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This screen shows detailed debug logs for tracking GPS, auto-ping, and service events. '
                  'If you\'re experiencing issues with auto-ping or GPS tracking, share the latest log file with the developer.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Current session: ${widget.locationService.debugLogPath?.split('/').last ?? 'Not started'}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logFiles.isEmpty
                    ? const Center(
                        child: Text(
                          'No debug logs found.\nStart tracking to generate logs.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logFiles.length,
                        itemBuilder: (context, index) {
                          final file = _logFiles[index];
                          final fileName = file.path.split('/').last;
                          final fileSize = file.lengthSync();
                          final modified = file.lastModifiedSync();

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.description, color: Colors.blue),
                              title: Text(
                                fileName,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                              subtitle: Text(
                                '${_formatFileSize(fileSize)} • ${_formatDateTime(modified)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'view':
                                      _viewLogFile(file);
                                      break;
                                    case 'share':
                                      _shareLogFile(file);
                                      break;
                                    case 'delete':
                                      _deleteLogFile(file);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.visibility, size: 20),
                                        SizedBox(width: 8),
                                        Text('View'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share, size: 20),
                                        SizedBox(width: 8),
                                        Text('Share'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _viewLogFile(file),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Simple log file viewer
class _LogViewerScreen extends StatelessWidget {
  final String fileName;
  final String content;

  const _LogViewerScreen({
    required this.fileName,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(
                content,
                subject: 'MeshCore Wardrive Debug Log: $fileName',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
