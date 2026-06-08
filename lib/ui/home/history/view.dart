import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../chat/models.dart';
import '../../chat/view.dart';
import '../../debug_log/view.dart';
import 'logic.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryLogic logic = Get.isRegistered<HistoryLogic>()
      ? Get.find<HistoryLogic>()
      : Get.put(HistoryLogic());
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    if (Get.isRegistered<HistoryLogic>()) {
      Get.delete<HistoryLogic>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final conversations = logic.state.conversations;
      final activeFilter = logic.state.activeFilter.value;
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'history.title'.tr,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'history.filter_by_tag'.tr,
                    onPressed: _showFilterDialog,
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  logic.setKeyword(value);
                },
                decoration: InputDecoration(
                  hintText: 'history.search_hint'.tr,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: logic.state.keyword.value.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            logic.setKeyword('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (activeFilter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(
                      'history.active_filter'.trParams({'tag': activeFilter}),
                    ),
                    onDeleted: logic.clearFilter,
                  ),
                ),
              ),
            Expanded(
              child: logic.state.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: logic.refreshHistory,
                      child: conversations.isEmpty
                          ? _buildEmptyState(theme)
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: conversations.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = conversations[index];
                                return _buildConversationCard(item, theme);
                              },
                            ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isSearching =
        logic.state.keyword.value.isNotEmpty ||
        logic.state.activeFilter.value != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(
          isSearching ? Icons.search_off : Icons.history_toggle_off,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            isSearching ? 'history.empty_search'.tr : 'history.empty'.tr,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildConversationCard(
    ChatConversationHistoryItem item,
    ThemeData theme,
  ) {
    final summary = item.summary;
    final title = summary.displayTag.isNotEmpty
        ? summary.displayTag
        : summary.title;
    final preview = item.lastMessage.isEmpty
        ? 'history.no_message'.tr
        : item.lastMessage;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openConversation(item),
        onLongPress: () => _showConversationMenu(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    if (summary.systemPromptTag.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          summary.systemPromptTag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatRelativeTime(summary.updatedAt),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openConversation(ChatConversationHistoryItem item) async {
    final summary = item.summary;
    await Get.to(
      () => const ChatPage(),
      arguments: {
        'conversationId': summary.id,
        'tag': summary.systemPromptTag,
        'content': summary.systemPromptContent,
        'displayTag': summary.displayTag,
      },
    );
    await logic.refreshHistory();
  }

  Future<void> _showFilterDialog() async {
    final tags = logic.state.tags.toList();
    final current = logic.state.activeFilter.value;
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('history.filter_by_tag'.tr),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(
                    current == null
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text('history.filter_all'.tr),
                  onTap: () => Navigator.of(context).pop<String?>(null),
                ),
                ...tags.map(
                  (tag) => ListTile(
                    leading: Icon(
                      current == tag
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(tag),
                    onTap: () => Navigator.of(context).pop<String?>(tag),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.cancel'.tr),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (selected != current) {
      await logic.setFilter(selected);
    }
  }

  Future<void> _showConversationMenu(ChatConversationHistoryItem item) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.bug_report_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text('history.menu.debug'.tr),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _openDebugLog(item);
                  if (!mounted) {
                    return;
                  }
                  await logic.refreshHistory();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text('history.menu.delete'.tr),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _showDeleteConfirm(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDebugLog(ChatConversationHistoryItem item) async {
    final summary = item.summary;
    final title = summary.displayTag.isNotEmpty
        ? summary.displayTag
        : summary.title;
    await Get.to<bool>(
      () => DebugLogPage(conversationId: summary.id, title: title),
    );
  }

  Future<void> _showDeleteConfirm(ChatConversationHistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('history.delete_title'.tr),
          content: Text('history.delete_message'.tr),
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
    await logic.deleteConversation(item.summary.id);
    if (!mounted) {
      return;
    }
    _showSnack('history.deleted'.tr);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatRelativeTime(int millis) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final todayStart = DateTime(now.year, now.month, now.day);
    final dayStart = DateTime(date.year, date.month, date.day);
    final diffDays = todayStart.difference(dayStart).inDays;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    if (diffDays == 0) {
      return '$hh:$mm';
    }
    if (diffDays == 1) {
      return 'history.time.yesterday'.tr;
    }
    if (diffDays == 2) {
      return 'history.time.day_before_yesterday'.tr;
    }
    return '${date.month}/${date.day} $hh:$mm';
  }
}
