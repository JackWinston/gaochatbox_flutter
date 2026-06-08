import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../util/debug_log_manager.dart';

class DebugLogPage extends StatefulWidget {
  const DebugLogPage({
    super.key,
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
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
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _displayText = displayText;
      _loading = false;
    });
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
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _buildEntryCard(entry, theme);
                },
              ),
            ),
    );
  }

  Widget _buildEntryCard(DebugLogEntry entry, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: entry.isError
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.type,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.timestamp,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.isError)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'debug_log.error'.tr,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSection(
              theme: theme,
              title: 'URL',
              content: entry.url,
              selectable: true,
            ),
            if ((entry.requestBody ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSection(
                theme: theme,
                title: 'debug_log.request'.tr,
                content: entry.requestBody!,
              ),
            ],
            if ((entry.responseBody ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSection(
                theme: theme,
                title: 'debug_log.response'.tr,
                content: entry.responseBody!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required String content,
    bool selectable = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: selectable
              ? SelectableText(
                  content,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                )
              : Text(content),
        ),
      ],
    );
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _displayText));
    if (!mounted) {
      return;
    }
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
    if (confirmed != true) {
      return;
    }
    await DebugLogManager.deleteLogFile(widget.conversationId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('debug_log.deleted'.tr)));
    Navigator.of(context).pop(true);
  }
}
