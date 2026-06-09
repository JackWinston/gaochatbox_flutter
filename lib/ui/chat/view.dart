import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'logic.dart';
import 'models.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatLogic logic;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  bool _wasNearBottom = true;
  int _lastItemCount = 0;
  bool _scrollScheduled = false;
  bool _initialHistoryScrollHandled = false;

  @override
  void initState() {
    super.initState();
    logic = Get.put(ChatLogic());
    _scrollController.addListener(() {
      _wasNearBottom = _isNearBottom();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    if (Get.isRegistered<ChatLogic>()) {
      Get.delete<ChatLogic>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Obx(() {
      final items = logic.state.chatItems;
      final streaming = logic.state.isStreaming.value;
      final initialTargetUserId = _initialHistoryScrollHandled
          ? null
          : _findLastUserMessageItemId(items);
      if (initialTargetUserId != null && !logic.state.isLoading.value) {
        _initialHistoryScrollHandled = true;
        _lastItemCount = items.length;
        _scheduleScrollToLastUserMessage(initialTargetUserId);
      } else if ((items.length != _lastItemCount || streaming) &&
          (_wasNearBottom || streaming)) {
        _lastItemCount = items.length;
        _scheduleScrollToBottom();
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(
            logic.state.title.value.isEmpty ? '聊天' : logic.state.title.value,
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditTitleDialog();
                } else if (value == 'delete') {
                  _showDeleteConfirmDialog();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑标题')),
                PopupMenuItem(value: 'delete', child: Text('删除会话')),
              ],
            ),
          ],
        ),
        body: logic.state.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                bottom: false,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return KeyedSubtree(
                      key: _itemKeyFor(item.id),
                      child: _buildItem(context, theme, item),
                    );
                  },
                ),
              ),
        bottomNavigationBar: logic.state.isLoading.value
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBottomChrome(theme),
                      _buildComposer(theme),
                    ],
                  ),
                ),
              ),
      );
    });
  }

  Widget _buildItem(BuildContext context, ThemeData theme, ChatItem item) {
    switch (item) {
      case TimestampChatItem():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.timeText,
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
        );
      case SystemPromptChatItem():
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: logic.toggleSystemPrompt,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.tag.isEmpty ? '系统提示词' : item.tag,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Icon(
                        item.isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.content.isEmpty ? '暂无提示词' : item.content,
                    maxLines: item.isExpanded ? null : 5,
                    overflow: item.isExpanded ? null : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        );
      case UserMessageChatItem():
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: theme.colorScheme.primaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.imageUri != null &&
                        item.imageUri!.isNotEmpty &&
                        File(item.imageUri!).existsSync()) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(item.imageUri!),
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (item.attachmentName != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.attachmentName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SelectableText(
                      item.content,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case AssistantMessageChatItem():
        final metaParts = <String>[];
        final settings = logic.state.renderSettings.value;
        if (settings.showCharCount) {
          metaParts.add('${item.content.length}字');
        }
        if (settings.showTokenCount && item.tokenCount > 0) {
          metaParts.add('${item.tokenCount}tok');
        }
        if (settings.showModelName && (item.modelName?.isNotEmpty ?? false)) {
          metaParts.add(item.modelName!);
        }
        if (settings.showTimestamp && item.createdAt > 0) {
          metaParts.add(_formatClock(item.createdAt));
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: GestureDetector(
                  onLongPress: () => _copyContent(item.content),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: item.content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          metaParts.join(' · '),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case StreamingMessageChatItem():
        final isStreamingActive = logic.state.isStreaming.value;
        final elapsedSeconds = item.thinkingStartTime <= 0
            ? 0
            : ((DateTime.now().millisecondsSinceEpoch - item.thinkingStartTime) /
                    1000)
                .floor();
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    onTap: logic.toggleStreamingExpanded,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Row(
                        children: [
                          if (isStreamingActive)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.auto_awesome,
                              color: theme.colorScheme.primary,
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isStreamingActive &&
                                      item.isThinking &&
                                      item.content.isEmpty
                                  ? '思考中'
                                  : isStreamingActive
                                  ? '正在回复'
                                  : '已完成',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isStreamingActive)
                            TextButton(
                              onPressed: _showStopStreamingDialog,
                              child: const Text('停止'),
                            ),
                          Icon(
                            item.isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (item.isExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.content.isNotEmpty)
                            SelectableText(
                              item.content,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            '等待 ${elapsedSeconds}s · ${item.charCount}字',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      case ToolCallMessageChatItem():
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build_circle_outlined,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.toolName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(_toolStatusText(item.status)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.arguments,
                      maxLines: 12,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.status == ToolCallStatus.executing ||
                        item.status == ToolCallStatus.pending) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                    if (item.result.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.result,
                          maxLines: 12,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildBottomChrome(ThemeData theme) {
    final hint = logic.state.contextCompressionHint.value;
    final phase = logic.state.pendingResponsePhase.value;
    final usage = logic.state.contextUsage.value;
    return Column(
      children: [
        if (phase != PendingResponsePhase.idle)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                switch (phase) {
                  PendingResponsePhase.thinking => '思考中',
                  PendingResponsePhase.executingTools => '执行工具中',
                  PendingResponsePhase.directAnswerFallback =>
                    '达到工具上限，正在直接回答',
                  PendingResponsePhase.idle => '',
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        if (hint != null && hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (usage.contextLimit > 0 && usage.currentTokens > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                LinearProgressIndicator(value: usage.percent / 100),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '上下文 ${usage.currentTokens}/${usage.contextLimit} (${usage.percent}%)',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildComposer(ThemeData theme) {
    final pendingAttachmentName = logic.pendingAttachmentName;
    final selectedModelName = logic.state.selectedModelName.value;
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingAttachmentName != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pendingAttachmentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: logic.clearPendingAttachment,
                      icon: const Icon(Icons.close),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '新建对话',
                  onPressed: _onNewChat,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
                IconButton(
                  tooltip: '选择图片',
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                IconButton(
                  tooltip: '选择文件',
                  onPressed: _pickTextFile,
                  icon: const Icon(Icons.description_outlined),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showModelSelectorDialog,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_outlined, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedModelName.isEmpty ? '未选择模型' : selectedModelName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '联网搜索',
                  onPressed: logic.toggleWebSearch,
                  icon: Icon(
                    Icons.travel_explore,
                    color: logic.state.webSearchEnabled.value
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                IconButton.filled(
                  onPressed: logic.state.isStreaming.value ? null : _sendMessage,
                  constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '输入消息',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text;
    if (text.trim().isEmpty && !logic.state.hasPendingAttachment.value) {
      return;
    }
    _inputController.clear();
    FocusScope.of(context).unfocus();
    await logic.sendMessage(text);
    _scheduleScrollToBottom(force: true);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('图片读取失败');
      return;
    }
    final extension = file.extension?.toLowerCase();
    final mediaType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    logic.attachImage(
      displayName: file.name,
      imageUri: file.path ?? '',
      imageBase64: base64Encode(bytes),
      mediaType: mediaType,
    );
    _showSnack('图片已加入下一条消息');
  }

  Future<void> _pickTextFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'txt',
        'md',
        'json',
        'csv',
        'yaml',
        'yml',
        'xml',
        'log',
        'kt',
        'java',
        'dart',
        'py',
        'js',
        'ts',
        'html',
        'css',
      ],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('文件内容为空或无法读取');
      return;
    }
    final content = utf8.decode(bytes, allowMalformed: true).trim();
    if (content.isEmpty) {
      _showSnack('文件内容为空或无法读取');
      return;
    }
    logic.attachTextFile(displayName: file.name, fileContent: content);
    _showSnack('文件已加入下一条消息');
  }

  void _showModelSelectorDialog() {
    final configs = logic.state.modelConfigs.toList();
    if (configs.isEmpty) {
      _showSnack('没有可用的模型配置');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择模型'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: configs.map((config) {
                final models = config.models.isEmpty && (config.defaultModel ?? '').isNotEmpty
                    ? [config.defaultModel!]
                    : config.models;
                if (models.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: 0,
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(
                        config.isDefault ? '${config.tag} (默认)' : config.tag,
                      ),
                      children: models.map((modelName) {
                        final selected =
                            logic.state.selectedModelName.value == modelName;
                        return ListTile(
                          title: Text(modelName),
                          trailing: selected
                              ? const Icon(Icons.check)
                              : (config.defaultModel == modelName
                                    ? const Icon(Icons.star, size: 18)
                                    : null),
                          onTap: () async {
                            await logic.selectModel(modelName, config);
                            if (!mounted) return;
                            Get.back<void>();
                            _showSnack('已选择: $modelName');
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showEditTitleDialog() {
    final controller = TextEditingController(text: logic.state.title.value);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑标题'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '输入标题',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final title = controller.text.trim();
                if (title.isEmpty) {
                  return;
                }
                await logic.updateTitle(title);
                if (!mounted) return;
                Get.back<void>();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog() {
    final pageNavigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: const Text('确认删除当前会话吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                await logic.deleteConversation();
                if (!mounted) {
                  return;
                }
                Get.back<void>();
                pageNavigator.maybePop();
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  void _showStopStreamingDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('停止生成'),
          content: const Text('确认停止当前回复吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                await logic.stopStreaming();
                if (!mounted) return;
                Get.back<void>();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onNewChat() async {
    final hasMessages = logic.state.chatItems.any(
      (item) => item is UserMessageChatItem || item is AssistantMessageChatItem,
    );
    if (!hasMessages) {
      await logic.restartChat();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建对话'),
          content: const Text('当前会话已有消息，确认开始新的对话吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await logic.restartChat();
    }
  }

  Future<void> _copyContent(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    _showSnack('已复制');
  }

  void _scheduleScrollToBottom({bool force = false}) {
    if (_scrollScheduled) {
      return;
    }
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_scrollController.hasClients) {
        return;
      }
      if (!force && !_wasNearBottom && !logic.state.isStreaming.value) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _scheduleScrollToLastUserMessage(String itemId) {
    if (_scrollScheduled) {
      return;
    }
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scrollScheduled = false;
      await _scrollToHistoryUserMessage(itemId);
    });
  }

  Future<void> _scrollToHistoryUserMessage(String itemId) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    _scrollController.jumpTo(position.maxScrollExtent);
    await _waitForNextFrame();

    for (var attempt = 0; attempt < 24; attempt++) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final targetContext = _itemKeys[itemId]?.currentContext;
      if (targetContext != null) {
        if (!targetContext.mounted) {
          return;
        }
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.08,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        return;
      }

      final currentPosition = _scrollController.position;
      if (currentPosition.pixels <= currentPosition.minScrollExtent) {
        return;
      }
      final nextOffset =
          (currentPosition.pixels - currentPosition.viewportDimension * 0.85)
              .clamp(
                currentPosition.minScrollExtent,
                currentPosition.maxScrollExtent,
              )
              .toDouble();
      if (nextOffset == currentPosition.pixels) {
        return;
      }
      _scrollController.jumpTo(nextOffset);
      await _waitForNextFrame();
    }
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  String? _findLastUserMessageItemId(List<ChatItem> items) {
    if (logic.state.conversationId.value.isEmpty) {
      return null;
    }
    for (var index = items.length - 1; index >= 0; index--) {
      final item = items[index];
      if (item is UserMessageChatItem) {
        return item.id;
      }
    }
    return null;
  }

  GlobalKey _itemKeyFor(String itemId) {
    return _itemKeys.putIfAbsent(itemId, GlobalKey.new);
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 80;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _toolStatusText(ToolCallStatus status) {
    switch (status) {
      case ToolCallStatus.pending:
        return '等待中';
      case ToolCallStatus.executing:
        return '执行中';
      case ToolCallStatus.completed:
        return '完成';
      case ToolCallStatus.error:
        return '失败';
    }
  }

  String _formatClock(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
