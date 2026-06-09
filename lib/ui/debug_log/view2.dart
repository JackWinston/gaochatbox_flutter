import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../util/debug_log_manager.dart';

/// 使用 Android / iOS 原生 View 实现的调试日志页面。
/// Android 侧：RecyclerView + CardView
/// iOS 侧：UITableView + UITableViewCell
class DebugLogNativePage extends StatefulWidget {
  const DebugLogNativePage({
    super.key,
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  State<DebugLogNativePage> createState() => _DebugLogNativePageState();
}

class _DebugLogNativePageState extends State<DebugLogNativePage> {
  static const _channel = MethodChannel('com.gao.chatbox/debug_log_view');

  bool _loading = true;
  List<DebugLogEntry> _entries = const [];
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final entries = await DebugLogManager.readLogFileRaw(widget.conversationId);
    final displayText = await DebugLogManager.buildDisplayText(
      widget.conversationId,
    );
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _displayText = displayText;
      _loading = false;
    });
  }

  /// 将日志条目序列化为原生端可解析的 JSON 列表。
  List<Map<String, dynamic>> _serializeEntries() {
    return _entries
        .map((e) => {
              'type': e.type,
              'timestamp': e.timestamp,
              'url': e.url,
              'requestBody': e.requestBody ?? '',
              'responseBody': e.responseBody ?? '',
              'isError': e.isError,
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('debug_log.title'.tr),
        actions: [
          IconButton(
            tooltip: 'debug_log.copy'.tr,
            onPressed: _entries.isEmpty ? null : _copyAll,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'debug_log.delete'.tr,
            onPressed: _entries.isEmpty ? null : _deleteLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text(
                    'debug_log.empty'.tr,
                    style: theme.textTheme.titleMedium,
                  ),
                )
              : _buildNativeView(theme),
    );
  }

  Widget _buildNativeView(ThemeData theme) {
    if (Platform.isAndroid) {
      return _buildAndroidView(theme);
    } else if (Platform.isIOS) {
      return _buildIOSView(theme);
    }
    // Web / Desktop fallback: 使用 Flutter 原生渲染
    return _buildFallbackList(theme);
  }

  /// Android 原生视图：RecyclerView + CardView
  Widget _buildAndroidView(ThemeData theme) {
    return AndroidView(
      viewType: 'com.gao.chatbox/debug_log_list',
      creationParams: <String, dynamic>{
        'entries': _serializeEntries(),
        'colors': _extractThemeColors(theme),
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        _setupMethodChannel();
      },
    );
  }

  /// iOS 原生视图：UITableView
  Widget _buildIOSView(ThemeData theme) {
    return UiKitView(
      viewType: 'com.gao.chatbox/debug_log_list',
      creationParams: <String, dynamic>{
        'entries': _serializeEntries(),
        'colors': _extractThemeColors(theme),
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        _setupMethodChannel();
      },
    );
  }

  Map<String, dynamic> _extractThemeColors(ThemeData theme) {
    final cs = theme.colorScheme;
    return {
      'surface': cs.surface.toARGB32(),
      'surfaceContainerLow': cs.surfaceContainerLow.toARGB32(),
      'onSurface': cs.onSurface.toARGB32(),
      'onSurfaceVariant': cs.onSurfaceVariant.toARGB32(),
      'primary': cs.primary.toARGB32(),
      'error': cs.error.toARGB32(),
      'errorContainer': cs.errorContainer.toARGB32(),
      'onErrorContainer': cs.onErrorContainer.toARGB32(),
      'outlineVariant': cs.outlineVariant.toARGB32(),
    };
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCopyEntry':
          final index = call.arguments as int;
          if (index >= 0 && index < _entries.length) {
            final entry = _entries[index];
            final text = StringBuffer()
              ..writeln(entry.type)
              ..writeln(entry.timestamp)
              ..writeln('URL: ${entry.url}');
            if (entry.requestBody?.isNotEmpty == true) {
              text
                ..writeln('Request:')
                ..writeln(entry.requestBody);
            }
            if (entry.responseBody?.isNotEmpty == true) {
              text
                ..writeln('Response:')
                ..writeln(entry.responseBody);
            }
            await Clipboard.setData(ClipboardData(text: text.toString()));
          }
          break;
        case 'onRefresh':
          await _loadLogs();
          break;
      }
    });
  }

  Widget _buildFallbackList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.type, style: theme.textTheme.titleMedium),
                Text(entry.timestamp, style: theme.textTheme.labelMedium),
                const SizedBox(height: 8),
                SelectableText(entry.url),
                if (entry.requestBody?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  SelectableText(entry.requestBody!),
                ],
                if (entry.responseBody?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  SelectableText(entry.responseBody!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _displayText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('debug_log.copied'.tr)));
  }

  Future<void> _deleteLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('debug_log.delete_title'.tr),
          content: Text(
            'debug_log.delete_message'.trParams({'title': widget.title}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('common.delete'.tr),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await DebugLogManager.deleteLogFile(widget.conversationId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('debug_log.deleted'.tr)));
    Navigator.of(context).pop(true);
  }
}
