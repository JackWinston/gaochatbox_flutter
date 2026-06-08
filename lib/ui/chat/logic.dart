import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import '../../data/model/model_config.dart';
import '../../data/repository/settings_repository.dart';
import '../../util/debug_log_manager.dart';
import '../../util/model_config_manager.dart';
import '../../util/model_context_limit_resolver.dart';
import 'chat_service.dart';
import 'context_compression_planner.dart';
import 'conversation_store.dart';
import 'models.dart';
import 'status.dart';

class ChatLogic extends GetxController {
  final ChatState state = ChatState();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final ModelConfigManager _modelConfigManager = ModelConfigManager();
  final ModelContextLimitResolver _contextLimitResolver =
      ModelContextLimitResolver();
  final ChatConversationStore _conversationStore = ChatConversationStore();
  final ChatService _chatService = ChatService();
  final ContextCompressionPlanner _compressionPlanner =
      const ContextCompressionPlanner();

  StreamSubscription<ChatStreamEvent>? _streamSubscription;
  PendingAttachment? _pendingAttachment;
  String _currentAssistantMessageId = '';
  String _accumulatedContent = '';
  int _thinkingStartTime = 0;
  bool _titleGenerated = false;
  bool _hasCustomTitle = false;
  String? _pendingToolFallbackMessage;
  String? _activeStreamingItemId;
  int _currentToolCallRoundCount = 0;
  final Map<int, _ToolCallBuilder> _pendingToolCalls = {};

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      state.promptTag.value = args['tag'] ?? '';
      state.systemPrompt.value = args['content'] ?? '';
      state.conversationId.value = args['conversationId']?.toString() ?? '';
      state.title.value = (args['displayTag'] ?? args['tag'] ?? '').toString();
    }
    if (state.title.value.isEmpty) {
      state.title.value = state.promptTag.value;
    }
    _initConversation();
  }

  Future<void> _initConversation() async {
    state.isLoading.value = true;
    final settings = await _settingsRepository.load();
    state.webSearchEnabled.value = settings.webSearchEnabled;
    state.maxToolCallRounds.value = settings.maxToolCallRounds;
    state.renderSettings.value = ChatRenderSettings(
      showCharCount: settings.showCharCount,
      showTokenCount: settings.showTokenCount,
      showModelName: settings.showModelName,
      showTimestamp: settings.showTimestamp,
    );
    await _modelConfigManager.init();
    final configs = await _modelConfigManager.getAll();
    state.modelConfigs.assignAll(configs);
    final defaultConfig = configs.cast<ModelConfig?>().firstWhereOrNull(
      (item) => item?.isDefault ?? false,
    );
    state.selectedModelName.value =
        defaultConfig?.defaultModel?.trim().isNotEmpty == true
        ? defaultConfig!.defaultModel!.trim()
        : (defaultConfig?.models.isNotEmpty == true
              ? defaultConfig!.models.first
              : '');
    if (state.conversationId.value.isNotEmpty) {
      await loadExistingConversation(state.conversationId.value);
    } else {
      buildInitialItems();
    }
    state.isLoading.value = false;
  }

  void buildInitialItems() {
    final items = <ChatItem>[
      _buildInitialTimestamp(),
      if (state.systemPrompt.value.trim().isNotEmpty)
        SystemPromptChatItem(
          content: state.systemPrompt.value,
          tag: state.promptTag.value,
        ),
    ];
    state.chatItems.assignAll(items);
  }

  Future<void> loadExistingConversation(String conversationId) async {
    _titleGenerated = true;
    final summary = await _conversationStore.getConversation(conversationId);
    if (summary != null) {
      state.title.value = summary.displayTag.isNotEmpty
          ? summary.displayTag
          : summary.title;
      state.systemPrompt.value = summary.systemPromptContent;
      state.promptTag.value = summary.systemPromptTag;
    }
    final messages = await _conversationStore.getMessages(conversationId);
    final toolResultMap = <String, StoredChatMessage>{
      for (final item in messages)
        if (item.role == 'tool' && (item.toolCallId?.isNotEmpty ?? false))
          item.toolCallId!: item,
    };
    final items = <ChatItem>[
      _buildInitialTimestamp(),
      if (state.systemPrompt.value.trim().isNotEmpty)
        SystemPromptChatItem(
          content: state.systemPrompt.value,
          tag: state.promptTag.value,
        ),
    ];
    for (final message in messages) {
      final timestamp = _buildTimestampIfNeeded(items, message.createdAt);
      if (timestamp != null) {
        items.add(timestamp);
      }
      if (message.role == 'user') {
        items.add(
          UserMessageChatItem(
            id: 'msg_${message.id}',
            content: message.displayContent ?? message.content,
            requestContent: message.content,
            attachmentName: message.attachmentName,
            imageUri: message.imageUri,
          ),
        );
        continue;
      }
      if (message.role == 'assistant') {
        if ((message.toolCallsJson ?? '').trim().isNotEmpty) {
          for (final toolCall in _parseToolCallsJson(message.toolCallsJson!)) {
            final toolId = toolCall['id'] ?? '';
            final resultMessage = toolResultMap[toolId];
            items.add(
              ToolCallMessageChatItem(
                id: 'tool_$toolId',
                toolName: toolCall['function.name'] ?? '',
                arguments: toolCall['function.arguments'] ?? '',
                result: resultMessage?.content ?? '',
                status: resultMessage == null
                    ? ToolCallStatus.pending
                    : ToolCallStatus.completed,
              ),
            );
          }
        } else if (message.content.trim().isNotEmpty) {
          items.add(
            AssistantMessageChatItem(
              id: 'msg_${message.id}',
              content: message.content,
              modelName: message.modelName,
              tokenCount: message.tokenCount,
              createdAt: message.createdAt,
            ),
          );
        }
      }
    }
    state.chatItems.assignAll(items);
    await refreshContextUsage();
  }

  Future<void> sendMessage(String text) async {
    if (state.isStreaming.value) {
      return;
    }
    final attachment = _pendingAttachment;
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachment == null) {
      return;
    }
    final config = _defaultConfig();
    if (config == null) {
      _showErrorMessage('没有可用的模型配置');
      return;
    }

    final items = state.chatItems.toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    final contextLimit = await _resolveContextLimit(config);
    final displayText = _buildDisplayMessageText(trimmed, attachment);
    final plannedRequest = _compressionPlanner.planInitialRequest(
      previousItems: items,
      text: trimmed,
      attachmentName: attachment?.displayName,
      fileContent: attachment?.fileContent,
      systemPrompt: _effectiveSystemPrompt(),
      contextLimit: contextLimit,
      enableWebSearch: state.webSearchEnabled.value,
      hasImageAttachment: attachment?.imageBase64 != null,
    );
    _updateContextCompressionHint(plannedRequest.report);

    final timestamp = _buildTimestampIfNeeded(items, now);
    if (timestamp != null) {
      items.add(timestamp);
    }
    items.add(
      UserMessageChatItem(
        id: 'msg_$now',
        content: displayText,
        requestContent: plannedRequest.userMessage,
        attachmentName: attachment?.displayName,
        imageUri: attachment?.imageUri,
      ),
    );
    state.chatItems.assignAll(items);

    final conversation = await _conversationStore.ensureConversation(
      conversationId: state.conversationId.value.isEmpty
          ? null
          : state.conversationId.value,
      fallbackTitle: _pendingConversationTitle(displayText),
      systemPromptContent: state.systemPrompt.value,
      systemPromptTag: state.promptTag.value,
      displayTag: _pendingDisplayTag(),
    );
    state.conversationId.value = conversation.id;
    if (!_hasCustomTitle) {
      state.title.value = conversation.displayTag.isNotEmpty
          ? conversation.displayTag
          : conversation.title;
    }

    await _conversationStore.addUserMessage(
      conversationId: conversation.id,
      content: plannedRequest.userMessage,
      displayContent: displayText,
      attachmentName: attachment?.displayName,
      imageUri: attachment?.imageUri,
    );
    _currentAssistantMessageId = await _conversationStore.addAssistantMessage(
      conversationId: conversation.id,
      content: '',
      modelName: state.selectedModelName.value.isEmpty
          ? null
          : state.selectedModelName.value,
      isStreaming: true,
    );

    clearPendingAttachment();
    state.isStreaming.value = true;
    state.pendingResponsePhase.value = PendingResponsePhase.thinking;
    _accumulatedContent = '';
    _thinkingStartTime = DateTime.now().millisecondsSinceEpoch;
    _activeStreamingItemId = null;
    _currentToolCallRoundCount = 0;
    _pendingToolCalls.clear();
    _pendingToolFallbackMessage = null;

    try {
      final stream = await _chatService.streamMessage(
        config: config,
        history: plannedRequest.history,
        userMessage: plannedRequest.userMessage,
        systemPrompt: _effectiveSystemPrompt().trim().isEmpty
            ? null
            : _effectiveSystemPrompt(),
        imageBase64: attachment?.imageBase64,
        mediaType: attachment?.mediaType,
        enableWebSearch: state.webSearchEnabled.value,
        conversationId: conversation.id,
      );
      await _startStreaming(stream: stream, config: config);
    } catch (e) {
      _showErrorMessage('请求失败: $e');
      await finishStreaming();
    }
  }

  Future<void> _startStreaming({
    required Stream<ChatStreamEvent> stream,
    required ModelConfig config,
    _ToolFollowUpContext? toolFollowUpContext,
    bool ignoreDisallowedToolCalls = false,
  }) async {
    await _streamSubscription?.cancel();
    _streamSubscription = stream.listen((event) async {
      switch (event) {
        case ContentDeltaEvent():
          _accumulatedContent += event.text;
          state.pendingResponsePhase.value = PendingResponsePhase.idle;
          _triggerStreamingUpdate();
        case ToolCallDeltaEvent():
          if (!state.webSearchEnabled.value && !ignoreDisallowedToolCalls) {
            _showErrorMessage('当前模型响应返回了未启用的工具调用。');
            await finishStreaming();
            return;
          }
          final builder = _pendingToolCalls.putIfAbsent(
            event.delta.index,
            _ToolCallBuilder.new,
          );
          if ((event.delta.id ?? '').isNotEmpty) {
            builder.id = event.delta.id!;
          }
          if ((event.delta.functionName ?? '').isNotEmpty) {
            builder.name = event.delta.functionName!;
          }
          if ((event.delta.arguments ?? '').isNotEmpty) {
            builder.arguments.write(event.delta.arguments!);
          }
        case StreamEndEvent():
          _pendingToolCalls.removeWhere((_, item) => item.name.trim().isEmpty);
          if (_pendingToolCalls.isNotEmpty) {
            if (_currentToolCallRoundCount >= state.maxToolCallRounds.value) {
              _pendingToolCalls.clear();
              if (toolFollowUpContext != null) {
                await _requestDirectAnswerAfterToolLimit(
                  config: config,
                  toolFollowUpContext: toolFollowUpContext,
                );
              } else {
                _showErrorMessage(
                  '已达到连续工具调用最大轮次（${state.maxToolCallRounds.value}次），已停止继续调用工具。',
                );
                await finishStreaming();
              }
              return;
            }
            _currentToolCallRoundCount++;
            await _handleToolCalls(config);
          } else {
            _triggerStreamingUpdate();
            await finishStreaming(tokenCount: event.usage?.completionTokens);
          }
        case StreamErrorEvent():
          _showErrorMessage(event.message);
          await finishStreaming();
      }
    });
  }

  void _triggerStreamingUpdate() {
    if (_accumulatedContent.trim().isEmpty) {
      return;
    }
    final items = state.chatItems.toList();
    final index = items.indexWhere((item) => item is StreamingMessageChatItem);
    if (index >= 0) {
      items[index] = (items[index] as StreamingMessageChatItem).copyWith(
        content: _accumulatedContent,
        isThinking: false,
        charCount: _accumulatedContent.length,
      );
    } else {
      final streamingId =
          _activeStreamingItemId ??
          'streaming_${DateTime.now().millisecondsSinceEpoch}';
      _activeStreamingItemId = streamingId;
      items.add(
        StreamingMessageChatItem(
          id: streamingId,
          content: _accumulatedContent,
          isThinking: false,
          thinkingStartTime: _thinkingStartTime,
          charCount: _accumulatedContent.length,
        ),
      );
    }
    state.chatItems.assignAll(items);
  }

  Future<void> _handleToolCalls(ModelConfig config) async {
    final items = state.chatItems.toList();
    final historyItems = items
        .where((item) => item is! StreamingMessageChatItem)
        .toList();
    items.removeWhere((item) => item is StreamingMessageChatItem);
    _activeStreamingItemId = null;
    final assistantToolCallContent = _accumulatedContent.trim().isEmpty
        ? null
        : _accumulatedContent;
    if (assistantToolCallContent != null) {
      items.add(
        AssistantMessageChatItem(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          content: assistantToolCallContent,
          modelName: state.selectedModelName.value.isEmpty
              ? null
              : state.selectedModelName.value,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    final sortedEntries = _pendingToolCalls.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final toolCalls = <ToolCall>[];
    for (final entry in sortedEntries) {
      final builder = entry.value;
      final toolCallId = builder.id.isEmpty
          ? 'call_${DateTime.now().millisecondsSinceEpoch}_${entry.key}'
          : builder.id;
      toolCalls.add(
        ToolCall(
          id: toolCallId,
          function: ToolCallFunction(
            name: builder.name,
            arguments: builder.arguments.toString(),
          ),
        ),
      );
      items.add(
        ToolCallMessageChatItem(
          id: 'tool_$toolCallId',
          toolName: builder.name,
          arguments: builder.arguments.toString(),
          status: ToolCallStatus.executing,
        ),
      );
    }
    state.chatItems.assignAll(items);
    state.pendingResponsePhase.value = PendingResponsePhase.executingTools;

    await _conversationStore.addToolCallMessage(
      conversationId: state.conversationId.value,
      assistantContent: assistantToolCallContent ?? '',
      toolCallsJson: jsonEncode(
        toolCalls.map((item) => item.toJson()).toList(),
      ),
      modelName: state.selectedModelName.value.isEmpty
          ? null
          : state.selectedModelName.value,
    );

    final outcomes = await Future.wait(
      toolCalls.map((toolCall) async {
        final result = await _chatService.executeTool(toolCall);
        return _ToolExecutionOutcome(
          toolCall: toolCall,
          result: result,
          isError: _isToolExecutionError(result),
        );
      }),
    );

    final toolResults = <String, String>{};
    final toolExecutionSummaries = <String>[];
    for (final outcome in outcomes) {
      toolResults[outcome.toolCall.id] = outcome.result;
      toolExecutionSummaries.add(
        '${outcome.toolCall.function.name}: ${outcome.result}',
      );
      await _conversationStore.addToolResultMessage(
        conversationId: state.conversationId.value,
        toolCallId: outcome.toolCall.id,
        content: outcome.result,
        name: outcome.toolCall.function.name,
      );
      final current = state.chatItems.toList();
      final index = current.indexWhere(
        (item) =>
            item is ToolCallMessageChatItem &&
            item.id == 'tool_${outcome.toolCall.id}',
      );
      if (index >= 0) {
        current[index] = (current[index] as ToolCallMessageChatItem).copyWith(
          result: outcome.result,
          status: outcome.isError
              ? ToolCallStatus.error
              : ToolCallStatus.completed,
        );
        state.chatItems.assignAll(current);
      }
    }
    _pendingToolFallbackMessage = _buildToolFallbackMessage(
      toolExecutionSummaries,
    );

    _currentAssistantMessageId = await _conversationStore.addAssistantMessage(
      conversationId: state.conversationId.value,
      content: '',
      modelName: state.selectedModelName.value.isEmpty
          ? null
          : state.selectedModelName.value,
      isStreaming: true,
    );
    _pendingToolCalls.clear();
    _accumulatedContent = '';
    _activeStreamingItemId = null;
    _thinkingStartTime = DateTime.now().millisecondsSinceEpoch;
    state.pendingResponsePhase.value = PendingResponsePhase.thinking;

    final plannedRequest = _compressionPlanner.planToolFollowUp(
      historyItems: historyItems,
      systemPrompt: _effectiveSystemPrompt(),
      contextLimit: await _resolveContextLimit(config),
      enableWebSearch: state.webSearchEnabled.value,
      reservedTexts: _buildReservedToolTexts(
        assistantToolCallContent: assistantToolCallContent,
        toolCalls: toolCalls,
        toolResults: toolResults,
      ),
    );
    _updateContextCompressionHint(plannedRequest.report);

    final toolFollowUpContext = _ToolFollowUpContext(
      history: plannedRequest.history,
      assistantContent: assistantToolCallContent,
      toolCalls: toolCalls,
      toolResults: toolResults,
    );
    try {
      final stream = await _chatService.streamToolFollowUp(
        config: config,
        history: plannedRequest.history,
        assistantContent: assistantToolCallContent,
        toolCalls: toolCalls,
        toolResults: toolResults,
        enableWebSearch: state.webSearchEnabled.value,
        conversationId: state.conversationId.value,
      );
      await _startStreaming(
        stream: stream,
        config: config,
        toolFollowUpContext: toolFollowUpContext,
      );
    } catch (e) {
      _showErrorMessage('工具结果请求失败: $e');
      await finishStreaming();
    }
  }

  Future<void> _requestDirectAnswerAfterToolLimit({
    required ModelConfig config,
    required _ToolFollowUpContext toolFollowUpContext,
  }) async {
    _discardStreamingMessage();
    _accumulatedContent = '';
    _pendingToolCalls.clear();
    _activeStreamingItemId = null;
    state.pendingResponsePhase.value =
        PendingResponsePhase.directAnswerFallback;
    try {
      final stream = await _chatService.streamToolFollowUp(
        config: config,
        history: toolFollowUpContext.history,
        assistantContent: toolFollowUpContext.assistantContent,
        toolCalls: toolFollowUpContext.toolCalls,
        toolResults: toolFollowUpContext.toolResults,
        enableWebSearch: false,
        conversationId: state.conversationId.value,
        directAnswerInstruction: '请基于已有工具结果直接给出最终回答，不要继续调用任何工具。',
      );
      await _startStreaming(
        stream: stream,
        config: config,
        ignoreDisallowedToolCalls: true,
      );
    } catch (e) {
      _showErrorMessage('达到工具轮次上限后，直接回答请求失败: $e');
      await finishStreaming();
    }
  }

  Future<void> finishStreaming({int? tokenCount}) async {
    final conversationId = state.conversationId.value;
    final items = state.chatItems.toList();
    final index = items.indexWhere((item) => item is StreamingMessageChatItem);
    final fallbackMessage = _pendingToolFallbackMessage;
    final finalContent = _accumulatedContent.isNotEmpty
        ? _accumulatedContent
        : (fallbackMessage ?? '');

    if (index >= 0) {
      if (finalContent.trim().isNotEmpty) {
        items[index] = AssistantMessageChatItem(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          content: finalContent,
          modelName: state.selectedModelName.value.isEmpty
              ? null
              : state.selectedModelName.value,
          tokenCount: tokenCount ?? 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        items.removeAt(index);
      }
    } else if (finalContent.trim().isNotEmpty) {
      items.add(
        AssistantMessageChatItem(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          content: finalContent,
          modelName: state.selectedModelName.value.isEmpty
              ? null
              : state.selectedModelName.value,
          tokenCount: tokenCount ?? 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    state.chatItems.assignAll(items);

    if (conversationId.isNotEmpty && _currentAssistantMessageId.isNotEmpty) {
      await _conversationStore.finishStreamingMessage(
        conversationId: conversationId,
        messageId: _currentAssistantMessageId,
        content: finalContent,
        tokenCount: tokenCount ?? 0,
      );
    }

    final userMessageCount = items.whereType<UserMessageChatItem>().length;
    if (userMessageCount == 1 && !_titleGenerated) {
      unawaited(_generateTitle(items));
    }

    state.isStreaming.value = false;
    state.pendingResponsePhase.value = PendingResponsePhase.idle;
    _accumulatedContent = '';
    _pendingToolCalls.clear();
    _pendingToolFallbackMessage = null;
    _activeStreamingItemId = null;
    _currentToolCallRoundCount = 0;
    await refreshContextUsage();
  }

  Future<void> refreshContextUsage() async {
    final conversationId = state.conversationId.value;
    if (conversationId.isEmpty) {
      state.contextUsage.value = const ChatContextUsageInfo();
      return;
    }
    final config = _defaultConfig();
    final contextLimit = config == null
        ? ModelContextLimitResolver.defaultContextLimit
        : await _resolveContextLimit(config);
    final totalTokens = await _conversationStore.getTotalTokens(conversationId);
    final percent = contextLimit <= 0
        ? 0
        : ((totalTokens / contextLimit) * 100).round().clamp(0, 100);
    state.contextUsage.value = ChatContextUsageInfo(
      currentTokens: totalTokens,
      contextLimit: contextLimit,
      percent: percent,
    );
  }

  void toggleSystemPrompt() {
    final items = state.chatItems.toList();
    final index = items.indexWhere((item) => item is SystemPromptChatItem);
    if (index < 0) {
      return;
    }
    final prompt = items[index] as SystemPromptChatItem;
    items[index] = prompt.copyWith(isExpanded: !prompt.isExpanded);
    state.chatItems.assignAll(items);
  }

  void toggleStreamingExpanded() {
    final items = state.chatItems.toList();
    final index = items.indexWhere((item) => item is StreamingMessageChatItem);
    if (index < 0) {
      return;
    }
    final streaming = items[index] as StreamingMessageChatItem;
    items[index] = streaming.copyWith(isExpanded: !streaming.isExpanded);
    state.chatItems.assignAll(items);
  }

  Future<void> toggleWebSearch() async {
    final next = !state.webSearchEnabled.value;
    state.webSearchEnabled.value = next;
    await _settingsRepository.setWebSearchEnabled(next);
  }

  Future<void> selectModel(String modelName, ModelConfig config) async {
    state.selectedModelName.value = modelName;
    final shouldKeepManualContext = config.contextLimitManuallySet != false;
    final resolvedContextLimit = shouldKeepManualContext
        ? config.contextLimit
        : await _contextLimitResolver.resolve(
            apiType: config.apiType,
            apiUrl: config.apiUrl,
            apiKey: config.apiKey,
            modelName: modelName,
          );
    final updated = config.copyWith(
      isDefault: true,
      defaultModel: modelName,
      contextLimit: resolvedContextLimit,
      detectedContextLimit: shouldKeepManualContext
          ? config.detectedContextLimit
          : resolvedContextLimit,
      contextLimitManuallySet: shouldKeepManualContext
          ? config.contextLimitManuallySet
          : false,
    );
    await _modelConfigManager.update(updated);
    final configs = await _modelConfigManager.getAll();
    state.modelConfigs.assignAll(configs);
    await refreshContextUsage();
  }

  Future<void> updateTitle(String newTitle) async {
    state.title.value = newTitle;
    _titleGenerated = true;
    _hasCustomTitle = true;
    if (state.conversationId.value.isNotEmpty) {
      await _conversationStore.updateConversationTitle(
        conversationId: state.conversationId.value,
        title: newTitle,
        displayTag: newTitle,
      );
    }
  }

  Future<void> deleteConversation() async {
    if (state.conversationId.value.isEmpty) {
      return;
    }
    await _conversationStore.deleteConversation(state.conversationId.value);
    await DebugLogManager.deleteLogFile(state.conversationId.value);
  }

  Future<void> restartChat() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    state.conversationId.value = '';
    _currentAssistantMessageId = '';
    _titleGenerated = false;
    _hasCustomTitle = false;
    _pendingAttachment = null;
    state.hasPendingAttachment.value = false;
    state.contextCompressionHint.value = null;
    state.contextUsage.value = const ChatContextUsageInfo();
    state.title.value = state.promptTag.value;
    buildInitialItems();
  }

  void attachImage({
    required String displayName,
    required String imageUri,
    required String imageBase64,
    required String? mediaType,
  }) {
    _pendingAttachment = PendingAttachment(
      displayName: displayName,
      imageUri: imageUri,
      imageBase64: imageBase64,
      mediaType: mediaType,
    );
    state.hasPendingAttachment.value = true;
  }

  void attachTextFile({
    required String displayName,
    required String fileContent,
  }) {
    _pendingAttachment = PendingAttachment(
      displayName: displayName,
      fileContent: fileContent,
    );
    state.hasPendingAttachment.value = true;
  }

  void clearPendingAttachment() {
    _pendingAttachment = null;
    state.hasPendingAttachment.value = false;
  }

  Future<void> stopStreaming() async {
    await _streamSubscription?.cancel();
    await finishStreaming();
  }

  String? get pendingAttachmentName => _pendingAttachment?.displayName;

  String _effectiveSystemPrompt() {
    if (state.systemPrompt.value.trim().isEmpty ||
        !state.webSearchEnabled.value) {
      return state.systemPrompt.value;
    }
    return [
      state.systemPrompt.value,
      '',
      '--- 可用工具 ---',
      '1. search_web(query: string) - 搜索互联网获取最新信息。当需要查询实时信息、新闻、天气等时使用',
      '2. fetch_webpage(url: string) - 抓取指定URL的网页内容。当需要读取某个网页的正文时使用',
      '每次会话最多可调用工具 ${state.maxToolCallRounds.value} 轮。请合理规划调用次数，优先使用最相关的工具获取信息。',
    ].join('\n');
  }

  Future<void> _generateTitle(List<ChatItem> items) async {
    final config = _defaultConfig();
    if (config == null) {
      return;
    }
    final userMessage = items
        .whereType<UserMessageChatItem>()
        .firstOrNull
        ?.content;
    if (userMessage == null || userMessage.trim().isEmpty) {
      return;
    }
    final assistantMessage =
        items.whereType<AssistantMessageChatItem>().lastOrNull?.content ?? '';
    final newTitle = await _chatService.generateTitle(
      config: config,
      userMessage: userMessage,
      assistantMessage: assistantMessage,
      conversationId: state.conversationId.value,
    );
    if (newTitle == null || newTitle.trim().isEmpty) {
      return;
    }
    _titleGenerated = true;
    state.title.value = newTitle.trim();
    if (state.conversationId.value.isNotEmpty) {
      await _conversationStore.updateConversationTitle(
        conversationId: state.conversationId.value,
        title: newTitle.trim(),
        displayTag: newTitle.trim(),
      );
    }
  }

  void _showErrorMessage(String message) {
    final items = state.chatItems.toList();
    items.removeWhere((item) => item is StreamingMessageChatItem);
    _activeStreamingItemId = null;
    items.add(
      AssistantMessageChatItem(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        content: '**Error:** $message',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    state.chatItems.assignAll(items);
  }

  void _discardStreamingMessage() {
    final items = state.chatItems.toList()
      ..removeWhere((item) => item is StreamingMessageChatItem);
    state.chatItems.assignAll(items);
  }

  void _updateContextCompressionHint(CompressionReport report) {
    final attachmentCompressed = report.attachmentStrategy == 'excerpt';
    final hasHistoryCompression = report.summarizedHistoryMessages > 0;
    if (hasHistoryCompression && attachmentCompressed) {
      state.contextCompressionHint.value =
          '历史消息保留 ${report.keptHistoryMessages} 条，压缩 ${report.summarizedHistoryMessages} 条，附件已按预算摘录。';
      return;
    }
    if (hasHistoryCompression) {
      state.contextCompressionHint.value =
          '历史消息保留 ${report.keptHistoryMessages} 条，压缩 ${report.summarizedHistoryMessages} 条。';
      return;
    }
    if (attachmentCompressed) {
      state.contextCompressionHint.value = '附件内容较长，已按上下文预算摘录。';
      return;
    }
    state.contextCompressionHint.value = null;
  }

  Future<int> _resolveContextLimit(ModelConfig config) async {
    final selectedModel = state.selectedModelName.value.trim();
    if ((config.contextLimit ?? 0) > 0 &&
        selectedModel == (config.defaultModel ?? '').trim()) {
      return config.contextLimit!;
    }
    return _contextLimitResolver.resolve(
      apiType: config.apiType,
      apiUrl: config.apiUrl,
      apiKey: config.apiKey,
      modelName: selectedModel.isNotEmpty
          ? selectedModel
          : ((config.defaultModel ?? '').trim().isNotEmpty
                ? config.defaultModel!.trim()
                : config.models.firstOrNull ?? ''),
    );
  }

  ModelConfig? _defaultConfig() {
    return state.modelConfigs.cast<ModelConfig?>().firstWhereOrNull(
      (item) => item?.isDefault ?? false,
    );
  }

  String _buildDisplayMessageText(String text, PendingAttachment? attachment) {
    if (text.trim().isNotEmpty) {
      return text.trim();
    }
    return attachment == null ? text : '请查看附件内容。';
  }

  String _pendingConversationTitle(String displayText) {
    if (_hasCustomTitle && state.title.value.trim().isNotEmpty) {
      return state.title.value.trim();
    }
    return displayText.trim().isEmpty
        ? state.promptTag.value
        : displayText.trim().substring(
            0,
            displayText.trim().length.clamp(0, 50),
          );
  }

  String _pendingDisplayTag() {
    if (state.title.value.trim().isNotEmpty) {
      return state.title.value.trim();
    }
    return state.promptTag.value;
  }

  List<Map<String, String>> _parseToolCallsJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) {
        return const [];
      }
      return decoded.whereType<Map<String, dynamic>>().map((item) {
        final function = item['function'];
        return {
          'id': item['id']?.toString() ?? '',
          'function.name': function is Map<String, dynamic>
              ? function['name']?.toString() ?? ''
              : '',
          'function.arguments': function is Map<String, dynamic>
              ? function['arguments']?.toString() ?? ''
              : '',
        };
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> _buildReservedToolTexts({
    required String? assistantToolCallContent,
    required List<ToolCall> toolCalls,
    required Map<String, String> toolResults,
  }) {
    final texts = <String>[
      if (assistantToolCallContent != null &&
          assistantToolCallContent.trim().isNotEmpty)
        assistantToolCallContent,
    ];
    for (final toolCall in toolCalls) {
      final buffer = StringBuffer()
        ..writeln(toolCall.function.name)
        ..writeln(toolCall.function.arguments);
      final result = toolResults[toolCall.id];
      if (result != null && result.trim().isNotEmpty) {
        buffer.writeln(result);
      }
      texts.add(buffer.toString().trim());
    }
    return texts;
  }

  bool _isToolExecutionError(String result) {
    return result.startsWith('搜索失败') ||
        result.startsWith('搜索执行失败') ||
        result.startsWith('网页内容获取失败') ||
        result.startsWith('未知工具') ||
        result.startsWith('搜索关键词为空') ||
        result.startsWith('URL 为空');
  }

  String _buildToolFallbackMessage(List<String> summaries) {
    if (summaries.isEmpty) {
      return '';
    }
    final buffer = StringBuffer()
      ..writeln('工具调用已完成，但模型没有返回最终总结。以下是工具结果：')
      ..writeln();
    for (var index = 0; index < summaries.length; index++) {
      buffer.writeln('${index + 1}. ${summaries[index]}');
    }
    return buffer.toString().trim();
  }

  TimestampChatItem _buildInitialTimestamp() {
    return _createTimestamp(DateTime.now().millisecondsSinceEpoch);
  }

  TimestampChatItem? _buildTimestampIfNeeded(List<ChatItem> items, int millis) {
    final timestamps = items.whereType<TimestampChatItem>().toList();
    if (timestamps.isEmpty) {
      return _createTimestamp(millis);
    }
    final lastTimestamp = timestamps.last;
    if (millis - lastTimestamp.timestampMillis > 5 * 60 * 1000) {
      return _createTimestamp(millis);
    }
    return null;
  }

  TimestampChatItem _createTimestamp(int millis) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final todayStart = DateTime(now.year, now.month, now.day);
    final diff = todayStart
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    String prefix;
    if (diff == 0) {
      prefix = '今天';
    } else if (diff == 1) {
      prefix = '昨天';
    } else if (diff == 2) {
      prefix = '前天';
    } else {
      prefix = '${date.month}月${date.day}日';
    }
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final text = diff <= 2 ? '$prefix $hh:$mm' : '$prefix $hh:$mm';
    return TimestampChatItem(
      id: 'ts_$millis',
      timeText: text,
      timestampMillis: millis,
    );
  }

  @override
  void onClose() {
    _streamSubscription?.cancel();
    super.onClose();
  }
}

class _ToolCallBuilder {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}

class _ToolExecutionOutcome {
  const _ToolExecutionOutcome({
    required this.toolCall,
    required this.result,
    required this.isError,
  });

  final ToolCall toolCall;
  final String result;
  final bool isError;
}

class _ToolFollowUpContext {
  const _ToolFollowUpContext({
    required this.history,
    required this.assistantContent,
    required this.toolCalls,
    required this.toolResults,
  });

  final List<OpenAiChatMessage> history;
  final String? assistantContent;
  final List<ToolCall> toolCalls;
  final Map<String, String> toolResults;
}
