import 'dart:math' as math;

import 'models.dart';

class ContextCompressionPlanner {
  const ContextCompressionPlanner();

  PlannedInitialRequest planInitialRequest({
    required List<ChatItem> previousItems,
    required String text,
    required String? attachmentName,
    required String? fileContent,
    required String systemPrompt,
    required int contextLimit,
    required bool enableWebSearch,
    required bool hasImageAttachment,
  }) {
    final normalizedContextLimit = math.max(contextLimit, 8192);
    final historyMessages = _extractConversationMessages(previousItems);
    final baseBudget = _calculateInputBudget(
      contextLimit: normalizedContextLimit,
      enableWebSearch: enableWebSearch,
      hasImageAttachment: hasImageAttachment,
      reservedExtraTokens: 0,
    );
    final userBudget = math.max(768, math.min(baseBudget ~/ 2, 24576));
    final attachmentPlan = _buildUserMessage(
      text: text,
      attachmentName: attachmentName,
      fileContent: fileContent,
      budgetTokens: userBudget,
    );
    final systemTokens = estimateTokens(systemPrompt);
    final userTokens = estimateTokens(attachmentPlan.message);
    final historyBudget = math.max(512, baseBudget - systemTokens - userTokens);
    final historyPlan = _compressHistory(historyMessages, historyBudget);
    final estimatedInputTokens =
        systemTokens + userTokens + _estimateMessageTokens(historyPlan.messages);
    final notes = <String>[];
    if (historyPlan.summarizedMessageCount > 0) {
      notes.add('较早历史已压缩为摘要');
    }
    if (attachmentPlan.strategy == 'excerpt') {
      notes.add('文本附件已按预算压缩');
    }
    return PlannedInitialRequest(
      userMessage: attachmentPlan.message,
      history: historyPlan.messages
          .map((item) => MessageContext(role: item.role, content: item.content))
          .toList(),
      report: CompressionReport(
        contextLimit: normalizedContextLimit,
        inputBudget: baseBudget,
        estimatedInputTokens: estimatedInputTokens,
        rawHistoryMessages: historyPlan.rawMessageCount,
        keptHistoryMessages: historyPlan.keptMessageCount,
        summarizedHistoryMessages: historyPlan.summarizedMessageCount,
        attachmentStrategy: attachmentPlan.strategy,
        hasImageAttachment: hasImageAttachment,
        notes: notes,
      ),
    );
  }

  PlannedToolRequest planToolFollowUp({
    required List<ChatItem> historyItems,
    required String systemPrompt,
    required int contextLimit,
    required bool enableWebSearch,
    required List<String> reservedTexts,
  }) {
    final normalizedContextLimit = math.max(contextLimit, 8192);
    final historyMessages = _extractConversationMessages(historyItems);
    final reservedExtraTokens =
        reservedTexts.fold<int>(0, (sum, item) => sum + estimateTokens(item));
    final baseBudget = _calculateInputBudget(
      contextLimit: normalizedContextLimit,
      enableWebSearch: enableWebSearch,
      hasImageAttachment: false,
      reservedExtraTokens: reservedExtraTokens,
    );
    final systemTokens = estimateTokens(systemPrompt);
    final historyBudget = math.max(512, baseBudget - systemTokens);
    final historyPlan = _compressHistory(historyMessages, historyBudget);
    final messages = <OpenAiChatMessage>[
      if (systemPrompt.trim().isNotEmpty)
        OpenAiChatMessage(role: 'system', content: systemPrompt),
      ...historyPlan.messages.map(
        (item) => OpenAiChatMessage(role: item.role, content: item.content),
      ),
    ];
    final notes = <String>[];
    if (historyPlan.summarizedMessageCount > 0) {
      notes.add('工具续轮前已压缩较早历史');
    }
    return PlannedToolRequest(
      history: messages,
      report: CompressionReport(
        contextLimit: normalizedContextLimit,
        inputBudget: baseBudget,
        estimatedInputTokens:
            systemTokens +
            _estimateMessageTokens(historyPlan.messages) +
            reservedExtraTokens,
        rawHistoryMessages: historyPlan.rawMessageCount,
        keptHistoryMessages: historyPlan.keptMessageCount,
        summarizedHistoryMessages: historyPlan.summarizedMessageCount,
        attachmentStrategy: 'none',
        hasImageAttachment: false,
        notes: notes,
      ),
    );
  }

  int estimateTokens(String text) {
    if (text.trim().isEmpty) {
      return 0;
    }
    var score = 0.0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char == '\n') {
        score += 0.25;
      } else if (rune <= 127) {
        score += 0.25;
      } else {
        score += 1.0;
      }
    }
    return score.ceil();
  }

  int _calculateInputBudget({
    required int contextLimit,
    required bool enableWebSearch,
    required bool hasImageAttachment,
    required int reservedExtraTokens,
  }) {
    final outputReserve = math.max(4096, math.min(contextLimit ~/ 8, 16384));
    final toolReserve = enableWebSearch ? 4096 : 1024;
    final imageReserve = hasImageAttachment ? 3072 : 0;
    final safetyReserve = math.max(1024, contextLimit ~/ 20);
    final inputBudget = contextLimit -
        outputReserve -
        toolReserve -
        imageReserve -
        safetyReserve -
        reservedExtraTokens;
    return math.max(inputBudget, 1024);
  }

  List<_ConversationMessage> _extractConversationMessages(List<ChatItem> items) {
    final messages = <_ConversationMessage>[];
    for (final item in items) {
      switch (item) {
        case UserMessageChatItem():
          messages.add(
            _ConversationMessage(role: 'user', content: item.requestContent),
          );
        case AssistantMessageChatItem():
          if (item.content.trim().isNotEmpty) {
            messages.add(
              _ConversationMessage(role: 'assistant', content: item.content),
            );
          }
        default:
          break;
      }
    }
    return messages;
  }

  _AttachmentPlan _buildUserMessage({
    required String text,
    required String? attachmentName,
    required String? fileContent,
    required int budgetTokens,
  }) {
    if (fileContent == null) {
      final message = text.trim().isNotEmpty
          ? _truncateToBudget(text, budgetTokens)
          : '请查看附件内容。';
      return _AttachmentPlan(message: message, strategy: 'none');
    }

    final prompt = text.trim().isNotEmpty ? text : '请结合附件文件内容进行处理。';
    final fullMessage = '$prompt\n\n[附件文件: ${attachmentName ?? "attachment.txt"}]\n$fileContent';
    if (estimateTokens(fullMessage) <= budgetTokens) {
      return _AttachmentPlan(message: fullMessage, strategy: 'full');
    }

    return _AttachmentPlan(
      message: _compressFileContent(
        prompt: prompt,
        attachmentName: attachmentName ?? 'attachment.txt',
        fileContent: fileContent,
        budgetTokens: budgetTokens,
      ),
      strategy: 'excerpt',
    );
  }

  _HistoryPlan _compressHistory(
    List<_ConversationMessage> history,
    int budgetTokens,
  ) {
    if (history.isEmpty || budgetTokens <= 0) {
      return _HistoryPlan(
        messages: const [],
        rawMessageCount: history.length,
        keptMessageCount: 0,
        summarizedMessageCount: 0,
      );
    }
    if (_estimateMessageTokens(history) <= budgetTokens) {
      return _HistoryPlan(
        messages: history,
        rawMessageCount: history.length,
        keptMessageCount: history.length,
        summarizedMessageCount: 0,
      );
    }

    final reserveForSummary = math.min(2048, math.max(256, budgetTokens ~/ 6));
    final keptReversed = <_ConversationMessage>[];
    var usedTokens = 0;
    final reversed = history.reversed.toList();
    for (var index = 0; index < reversed.length; index++) {
      final message = reversed[index];
      final remainingOldMessages = history.length - keptReversed.length - 1;
      final reserve = remainingOldMessages > 0 ? reserveForSummary : 0;
      final cost = estimateTokens(message.content) + 6;
      if (index > 0 && usedTokens + cost + reserve > budgetTokens) {
        continue;
      }
      if (usedTokens + cost > budgetTokens) {
        continue;
      }
      keptReversed.add(message);
      usedTokens += cost;
    }

    final keptMessages = keptReversed.reversed.toList();
    final summarizedCount = history.length - keptMessages.length;
    if (summarizedCount <= 0) {
      return _HistoryPlan(
        messages: keptMessages,
        rawMessageCount: history.length,
        keptMessageCount: keptMessages.length,
        summarizedMessageCount: 0,
      );
    }

    final olderMessages = history.take(summarizedCount).toList();
    final summaryBudget =
        math.max(192, budgetTokens - _estimateMessageTokens(keptMessages));
    final summary = _buildHistorySummary(olderMessages, summaryBudget);
    final plannedMessages = <_ConversationMessage>[
      if (summary.isNotEmpty)
        _ConversationMessage(role: 'assistant', content: summary),
      ...keptMessages,
    ];

    while (plannedMessages.isNotEmpty &&
        _estimateMessageTokens(plannedMessages) > budgetTokens &&
        plannedMessages.length > 1) {
      final removableIndex = plannedMessages.indexWhere(
        (item) =>
            item.role != 'assistant' ||
            !item.content.startsWith('[较早历史摘要]'),
      );
      if (removableIndex <= 0) {
        break;
      }
      plannedMessages.removeAt(removableIndex);
    }

    if (plannedMessages.isNotEmpty &&
        _estimateMessageTokens(plannedMessages) > budgetTokens &&
        plannedMessages.first.content.startsWith('[较早历史摘要]')) {
      plannedMessages[0] = _ConversationMessage(
        role: plannedMessages.first.role,
        content: _truncateToBudget(
          plannedMessages.first.content,
          math.max(160, budgetTokens ~/ 2),
        ),
      );
    }

    return _HistoryPlan(
      messages: plannedMessages,
      rawMessageCount: history.length,
      keptMessageCount: plannedMessages
          .where((item) => !item.content.startsWith('[较早历史摘要]'))
          .length,
      summarizedMessageCount: summarizedCount,
    );
  }

  String _buildHistorySummary(
    List<_ConversationMessage> messages,
    int budgetTokens,
  ) {
    if (messages.isEmpty || budgetTokens <= 0) {
      return '';
    }
    final userSnippets = messages
        .where((item) => item.role == 'user')
        .toList()
        .reversed
        .take(3)
        .toList()
        .reversed
        .map((item) => _condenseMessage(item.content, 220))
        .toList();
    final assistantSnippets = messages
        .where((item) => item.role == 'assistant')
        .toList()
        .reversed
        .take(3)
        .toList()
        .reversed
        .map((item) => _condenseMessage(item.content, 220))
        .toList();
    final buffer = StringBuffer('[较早历史摘要]\n');
    buffer.writeln('- 已压缩消息数: ${messages.length}');
    if (userSnippets.isNotEmpty) {
      buffer.writeln('- 较早用户诉求:');
      for (final item in userSnippets) {
        buffer.writeln('  - $item');
      }
    }
    if (assistantSnippets.isNotEmpty) {
      buffer.writeln('- 较早助手结论:');
      for (final item in assistantSnippets) {
        buffer.writeln('  - $item');
      }
    }
    return _truncateToBudget(buffer.toString().trim(), budgetTokens);
  }

  String _compressFileContent({
    required String prompt,
    required String attachmentName,
    required String fileContent,
    required int budgetTokens,
  }) {
    final lines = fileContent.split('\n');
    final keywords = _extractKeywords(prompt);
    final headLines = lines.take(80).toList();
    final tailLines = lines.skip(math.max(0, lines.length - 40)).toList();
    final matchedIndexes = <int>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final matched = keywords.any(
        (keyword) =>
            keyword.isNotEmpty && line.toLowerCase().contains(keyword),
      );
      if (matched) {
        matchedIndexes.add(index);
      }
    }
    final excerptIndexes = <int>{};
    for (final index in matchedIndexes.take(24)) {
      final start = math.max(0, index - 2);
      final end = math.min(lines.length - 1, index + 2);
      for (var lineIndex = start; lineIndex <= end; lineIndex++) {
        excerptIndexes.add(lineIndex);
      }
    }
    final excerptLines = excerptIndexes.toList()
      ..sort();
    final clippedExcerptLines = excerptLines.take(120).map(
      (index) => '${index + 1}: ${lines[index]}',
    );
    final buffer = StringBuffer()
      ..writeln(prompt)
      ..writeln()
      ..writeln('[附件文件: $attachmentName]')
      ..writeln('[文件摘要]')
      ..writeln('- 总行数: ${lines.length}')
      ..writeln('- 总字符数: ${fileContent.length}')
      ..writeln('- 已按上下文预算截取关键片段，优先保留头部、尾部和与当前问题相关的行。');
    if (keywords.isNotEmpty) {
      buffer.writeln('- 关键词: ${keywords.join(", ")}');
    }
    buffer
      ..writeln()
      ..writeln('[头部片段]')
      ..writeln(headLines.join('\n'));
    if (excerptIndexes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[命中片段]')
        ..writeln(clippedExcerptLines.join('\n'));
    }
    buffer
      ..writeln()
      ..writeln('[尾部片段]')
      ..write(tailLines.join('\n'));
    return _truncateToBudget(buffer.toString(), budgetTokens);
  }

  List<String> _extractKeywords(String prompt) {
    final cleaned = prompt
        .replaceAll('\n', ' ')
        .split(RegExp('[\\s,.;:!?()\\[\\]{}<>"\\\'`/\\\\|]+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 2)
        .toSet()
        .toList();
    final prioritized = cleaned.where((token) {
      final hasNonAscii = token.runes.any((rune) => rune > 127);
      return hasNonAscii || token.length >= 4;
    }).toList();
    return prioritized.take(8).map((item) => item.toLowerCase()).toList();
  }

  String _condenseMessage(String text, int maxChars) {
    final normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('```', '')
        .trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 8)}...(已截断)';
  }

  String _truncateToBudget(String text, int budgetTokens) {
    if (text.trim().isEmpty || estimateTokens(text) <= budgetTokens) {
      return text;
    }
    final approxChars = math.max(160, budgetTokens * 3);
    if (text.length <= approxChars) {
      return text;
    }
    final headSize = math.max(96, approxChars * 2 ~/ 3);
    final tailSize = math.max(48, approxChars ~/ 3);
    final head = text.substring(0, math.min(headSize, text.length));
    final tailStart = math.max(head.length, text.length - tailSize);
    final tail = text.substring(tailStart);
    return '${head.trimRight()}\n\n[内容已按上下文预算截断]\n\n${tail.trimLeft()}';
  }

  int _estimateMessageTokens(List<_ConversationMessage> messages) {
    return messages.fold<int>(
      0,
      (sum, item) => sum + estimateTokens(item.content) + 6,
    );
  }
}

class PlannedInitialRequest {
  const PlannedInitialRequest({
    required this.userMessage,
    required this.history,
    required this.report,
  });

  final String userMessage;
  final List<MessageContext> history;
  final CompressionReport report;
}

class PlannedToolRequest {
  const PlannedToolRequest({
    required this.history,
    required this.report,
  });

  final List<OpenAiChatMessage> history;
  final CompressionReport report;
}

class CompressionReport {
  const CompressionReport({
    required this.contextLimit,
    required this.inputBudget,
    required this.estimatedInputTokens,
    required this.rawHistoryMessages,
    required this.keptHistoryMessages,
    required this.summarizedHistoryMessages,
    required this.attachmentStrategy,
    required this.hasImageAttachment,
    required this.notes,
  });

  final int contextLimit;
  final int inputBudget;
  final int estimatedInputTokens;
  final int rawHistoryMessages;
  final int keptHistoryMessages;
  final int summarizedHistoryMessages;
  final String attachmentStrategy;
  final bool hasImageAttachment;
  final List<String> notes;
}

class _ConversationMessage {
  const _ConversationMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;
}

class _HistoryPlan {
  const _HistoryPlan({
    required this.messages,
    required this.rawMessageCount,
    required this.keptMessageCount,
    required this.summarizedMessageCount,
  });

  final List<_ConversationMessage> messages;
  final int rawMessageCount;
  final int keptMessageCount;
  final int summarizedMessageCount;
}

class _AttachmentPlan {
  const _AttachmentPlan({
    required this.message,
    required this.strategy,
  });

  final String message;
  final String strategy;
}
