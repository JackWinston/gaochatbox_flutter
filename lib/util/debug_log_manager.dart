import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DebugLogEntry {
  const DebugLogEntry({
    required this.timestamp,
    required this.type,
    required this.url,
    this.requestBody,
    this.responseBody,
    this.isError = false,
  });

  final String timestamp;
  final String type;
  final String url;
  final String? requestBody;
  final String? responseBody;
  final bool isError;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'type': type,
    'url': url,
    'requestBody': requestBody,
    'responseBody': responseBody,
    'isError': isError,
  };

  factory DebugLogEntry.fromJson(Map<String, dynamic> json) {
    return DebugLogEntry(
      timestamp: json['timestamp']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      requestBody: json['requestBody']?.toString(),
      responseBody: json['responseBody']?.toString(),
      isError: json['isError'] as bool? ?? false,
    );
  }
}

class DebugLogManager {
  static const _directoryName = 'debug_logs';

  static Future<List<DebugLogEntry>> readLogFileRaw(
    String conversationId,
  ) async {
    final file = await _getLogFile(conversationId);
    if (!await file.exists()) {
      return const [];
    }
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DebugLogEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> appendLog({
    required String conversationId,
    required String type,
    required String url,
    String? requestBody,
    String? responseBody,
    bool isError = false,
  }) async {
    final file = await _getLogFile(conversationId);
    final entries = (await readLogFileRaw(conversationId)).toList();
    entries.add(
      DebugLogEntry(
        timestamp: _formatTimestamp(DateTime.now()),
        type: type,
        url: url,
        requestBody: _formatJsonOrNull(requestBody),
        responseBody: _formatJsonOrNull(responseBody),
        isError: isError,
      ),
    );
    await file.writeAsString(
      jsonEncode(entries.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }

  static Future<void> deleteLogFile(String conversationId) async {
    final file = await _getLogFile(conversationId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<String> buildDisplayText(String conversationId) async {
    final entries = await readLogFileRaw(conversationId);
    if (entries.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (index > 0) {
        buffer
          ..writeln()
          ..writeln(List.filled(80, '-').join())
          ..writeln();
      }
      buffer.writeln('[${entry.timestamp}] ${entry.type}');
      buffer.writeln('URL: ${entry.url}');
      if (entry.isError) {
        buffer.writeln('ERROR');
      }
      if (entry.requestBody != null && entry.requestBody!.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('Request:')
          ..writeln(entry.requestBody);
      }
      if (entry.responseBody != null && entry.responseBody!.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('Response:')
          ..writeln(entry.responseBody);
      }
    }
    return buffer.toString().trim();
  }

  static Future<File> _getLogFile(String conversationId) async {
    final dir = await _getLogDir();
    final safeId = Uri.encodeComponent(conversationId);
    return File('${dir.path}/conv_$safeId.json');
  }

  static Future<Directory> _getLogDir() async {
    final baseDir = await getTemporaryDirectory();
    final dir = Directory('${baseDir.path}/$_directoryName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String? _formatJsonOrNull(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  static String _formatTimestamp(DateTime dateTime) {
    final yyyy = dateTime.year.toString().padLeft(4, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    final ss = dateTime.second.toString().padLeft(2, '0');
    final ms = dateTime.millisecond.toString().padLeft(3, '0');
    return '$yyyy-$mm-$dd $hh:$min:$ss.$ms';
  }
}
