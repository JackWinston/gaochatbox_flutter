import 'dart:convert';

class ChatRenderSettings {
  const ChatRenderSettings({
    this.showCharCount = false,
    this.showTokenCount = false,
    this.showModelName = false,
    this.showTimestamp = false,
  });

  final bool showCharCount;
  final bool showTokenCount;
  final bool showModelName;
  final bool showTimestamp;
}

class ChatContextUsageInfo {
  const ChatContextUsageInfo({
    this.currentTokens = 0,
    this.contextLimit = 0,
    this.percent = 0,
  });

  final int currentTokens;
  final int contextLimit;
  final int percent;
}

enum PendingResponsePhase {
  idle,
  thinking,
  executingTools,
  directAnswerFallback,
}

enum ToolCallStatus { pending, executing, completed, error }

sealed class ChatItem {
  const ChatItem(this.id);

  final String id;
}

class TimestampChatItem extends ChatItem {
  const TimestampChatItem({
    required String id,
    required this.timeText,
    required this.timestampMillis,
  }) : super(id);

  final String timeText;
  final int timestampMillis;
}

class SystemPromptChatItem extends ChatItem {
  const SystemPromptChatItem({
    String id = 'system_prompt',
    required this.content,
    required this.tag,
    this.isExpanded = false,
  }) : super(id);

  final String content;
  final String tag;
  final bool isExpanded;

  SystemPromptChatItem copyWith({
    String? content,
    String? tag,
    bool? isExpanded,
  }) {
    return SystemPromptChatItem(
      id: id,
      content: content ?? this.content,
      tag: tag ?? this.tag,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class UserMessageChatItem extends ChatItem {
  const UserMessageChatItem({
    required String id,
    required this.content,
    required this.requestContent,
    this.attachmentName,
    this.imageUri,
  }) : super(id);

  final String content;
  final String requestContent;
  final String? attachmentName;
  final String? imageUri;
}

class AssistantMessageChatItem extends ChatItem {
  const AssistantMessageChatItem({
    required String id,
    required this.content,
    this.modelName,
    this.tokenCount = 0,
    this.createdAt = 0,
  }) : super(id);

  final String content;
  final String? modelName;
  final int tokenCount;
  final int createdAt;
}

class StreamingMessageChatItem extends ChatItem {
  const StreamingMessageChatItem({
    String id = 'streaming',
    this.content = '',
    this.isThinking = true,
    this.thinkingStartTime = 0,
    this.charCount = 0,
    this.isExpanded = false,
  }) : super(id);

  final String content;
  final bool isThinking;
  final int thinkingStartTime;
  final int charCount;
  final bool isExpanded;

  StreamingMessageChatItem copyWith({
    String? content,
    bool? isThinking,
    int? thinkingStartTime,
    int? charCount,
    bool? isExpanded,
  }) {
    return StreamingMessageChatItem(
      id: id,
      content: content ?? this.content,
      isThinking: isThinking ?? this.isThinking,
      thinkingStartTime: thinkingStartTime ?? this.thinkingStartTime,
      charCount: charCount ?? this.charCount,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class ToolCallMessageChatItem extends ChatItem {
  const ToolCallMessageChatItem({
    required String id,
    required this.toolName,
    required this.arguments,
    this.result = '',
    this.status = ToolCallStatus.pending,
  }) : super(id);

  final String toolName;
  final String arguments;
  final String result;
  final ToolCallStatus status;

  ToolCallMessageChatItem copyWith({
    String? toolName,
    String? arguments,
    String? result,
    ToolCallStatus? status,
  }) {
    return ToolCallMessageChatItem(
      id: id,
      toolName: toolName ?? this.toolName,
      arguments: arguments ?? this.arguments,
      result: result ?? this.result,
      status: status ?? this.status,
    );
  }
}

class PendingAttachment {
  const PendingAttachment({
    required this.displayName,
    this.imageUri,
    this.imageBase64,
    this.mediaType,
    this.fileContent,
  });

  final String displayName;
  final String? imageUri;
  final String? imageBase64;
  final String? mediaType;
  final String? fileContent;
}

class ChatConversationSummary {
  const ChatConversationSummary({
    required this.id,
    required this.title,
    required this.systemPromptContent,
    required this.systemPromptTag,
    required this.displayTag,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String systemPromptContent;
  final String systemPromptTag;
  final String displayTag;
  final int createdAt;
  final int updatedAt;

  ChatConversationSummary copyWith({
    String? id,
    String? title,
    String? systemPromptContent,
    String? systemPromptTag,
    String? displayTag,
    int? createdAt,
    int? updatedAt,
  }) {
    return ChatConversationSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      systemPromptContent: systemPromptContent ?? this.systemPromptContent,
      systemPromptTag: systemPromptTag ?? this.systemPromptTag,
      displayTag: displayTag ?? this.displayTag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'systemPromptContent': systemPromptContent,
    'systemPromptTag': systemPromptTag,
    'displayTag': displayTag,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory ChatConversationSummary.fromJson(Map<String, dynamic> json) {
    return ChatConversationSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      systemPromptContent: json['systemPromptContent']?.toString() ?? '',
      systemPromptTag: json['systemPromptTag']?.toString() ?? '',
      displayTag: json['displayTag']?.toString() ?? '',
      createdAt: _readInt(json['createdAt']),
      updatedAt: _readInt(json['updatedAt']),
    );
  }
}

class ChatConversationHistoryItem {
  const ChatConversationHistoryItem({
    required this.summary,
    required this.lastMessage,
  });

  final ChatConversationSummary summary;
  final String lastMessage;
}

class StoredChatMessage {
  const StoredChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.displayContent,
    this.attachmentName,
    this.imageUri,
    this.modelName,
    this.tokenCount = 0,
    required this.createdAt,
    this.toolCallsJson,
    this.toolCallId,
    this.name,
    this.isStreaming = false,
  });

  final String id;
  final String role;
  final String content;
  final String? displayContent;
  final String? attachmentName;
  final String? imageUri;
  final String? modelName;
  final int tokenCount;
  final int createdAt;
  final String? toolCallsJson;
  final String? toolCallId;
  final String? name;
  final bool isStreaming;

  StoredChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    String? displayContent,
    String? attachmentName,
    String? imageUri,
    String? modelName,
    int? tokenCount,
    int? createdAt,
    String? toolCallsJson,
    String? toolCallId,
    String? name,
    bool? isStreaming,
  }) {
    return StoredChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      displayContent: displayContent ?? this.displayContent,
      attachmentName: attachmentName ?? this.attachmentName,
      imageUri: imageUri ?? this.imageUri,
      modelName: modelName ?? this.modelName,
      tokenCount: tokenCount ?? this.tokenCount,
      createdAt: createdAt ?? this.createdAt,
      toolCallsJson: toolCallsJson ?? this.toolCallsJson,
      toolCallId: toolCallId ?? this.toolCallId,
      name: name ?? this.name,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'displayContent': displayContent,
    'attachmentName': attachmentName,
    'imageUri': imageUri,
    'modelName': modelName,
    'tokenCount': tokenCount,
    'createdAt': createdAt,
    'toolCallsJson': toolCallsJson,
    'toolCallId': toolCallId,
    'name': name,
    'isStreaming': isStreaming,
  };

  factory StoredChatMessage.fromJson(Map<String, dynamic> json) {
    return StoredChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      displayContent: json['displayContent']?.toString(),
      attachmentName: json['attachmentName']?.toString(),
      imageUri: json['imageUri']?.toString(),
      modelName: json['modelName']?.toString(),
      tokenCount: _readInt(json['tokenCount']),
      createdAt: _readInt(json['createdAt']),
      toolCallsJson: json['toolCallsJson']?.toString(),
      toolCallId: json['toolCallId']?.toString(),
      name: json['name']?.toString(),
      isStreaming: json['isStreaming'] as bool? ?? false,
    );
  }

  static List<StoredChatMessage> listFromJson(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StoredChatMessage.fromJson)
        .toList();
  }

  static String listToJson(List<StoredChatMessage> messages) {
    return jsonEncode(messages.map((item) => item.toJson()).toList());
  }
}

class MessageContext {
  const MessageContext({
    required this.role,
    required this.content,
    this.imageBase64,
    this.mediaType,
  });

  final String role;
  final String content;
  final String? imageBase64;
  final String? mediaType;
}

class OpenAiChatMessage {
  const OpenAiChatMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
  });

  final String role;
  final Object? content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? name;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (toolCalls != null)
      'tool_calls': toolCalls!.map((item) => item.toJson()).toList(),
    if (toolCallId != null) 'tool_call_id': toolCallId,
    if (name != null) 'name': name,
  };
}

class ToolDefinition {
  const ToolDefinition({this.type = 'function', required this.function});

  final String type;
  final ToolFunctionDefinition function;

  Map<String, dynamic> toJson() => {
    'type': type,
    'function': function.toJson(),
  };
}

class ToolFunctionDefinition {
  const ToolFunctionDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

class ToolCall {
  const ToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
  });

  final String id;
  final String type;
  final ToolCallFunction function;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'function': function.toJson(),
  };
}

class ToolCallFunction {
  const ToolCallFunction({required this.name, required this.arguments});

  final String name;
  final String arguments;

  Map<String, dynamic> toJson() => {'name': name, 'arguments': arguments};
}

class ToolCallDelta {
  const ToolCallDelta({
    required this.index,
    this.id,
    this.functionName,
    this.arguments,
  });

  final int index;
  final String? id;
  final String? functionName;
  final String? arguments;
}

class TokenUsage {
  const TokenUsage({this.promptTokens = 0, this.completionTokens = 0});

  final int promptTokens;
  final int completionTokens;
}

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ContentDeltaEvent extends ChatStreamEvent {
  const ContentDeltaEvent(this.text);

  final String text;
}

class ToolCallDeltaEvent extends ChatStreamEvent {
  const ToolCallDeltaEvent(this.delta);

  final ToolCallDelta delta;
}

class StreamEndEvent extends ChatStreamEvent {
  const StreamEndEvent({this.usage, this.finishReason});

  final TokenUsage? usage;
  final String? finishReason;
}

class StreamErrorEvent extends ChatStreamEvent {
  const StreamErrorEvent(this.message);

  final String message;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
