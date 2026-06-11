import 'dart:async';
import 'dart:convert';
import '../../data/model/model_config.dart';
import '../../data/remote/api_client.dart';
import '../../util/debug_log_manager.dart';
import '../../util/web_search_tool.dart';
import 'models.dart';

class ChatService {
  ChatService();

  final WebSearchTool _webSearchTool = WebSearchTool();

  Future<Stream<ChatStreamEvent>> streamMessage({
    required ModelConfig config,
    required List<MessageContext> history,
    required String userMessage,
    required String? systemPrompt,
    required String? imageBase64,
    required String? mediaType,
    required bool enableWebSearch,
    required String conversationId,
  }) async {
    switch (config.apiType) {
      case ModelConfig.apiTypeAnthropic:
        return _streamAnthropicMessage(
          config: config,
          history: history,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          imageBase64: imageBase64,
          mediaType: mediaType,
          enableWebSearch: enableWebSearch,
          conversationId: conversationId,
        );
      default:
        return _streamOpenAiMessage(
          config: config,
          history: history,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          imageBase64: imageBase64,
          mediaType: mediaType,
          enableWebSearch: enableWebSearch,
          conversationId: conversationId,
        );
    }
  }

  Future<Stream<ChatStreamEvent>> streamToolFollowUp({
    required ModelConfig config,
    required List<OpenAiChatMessage> history,
    required String? assistantContent,
    required List<ToolCall> toolCalls,
    required Map<String, String> toolResults,
    required bool enableWebSearch,
    required String conversationId,
    String? directAnswerInstruction,
  }) async {
    switch (config.apiType) {
      case ModelConfig.apiTypeAnthropic:
        return _streamAnthropicToolFollowUp(
          config: config,
          history: history,
          assistantContent: assistantContent,
          toolCalls: toolCalls,
          toolResults: toolResults,
          conversationId: conversationId,
          directAnswerInstruction: directAnswerInstruction,
        );
      default:
        return _streamOpenAiToolFollowUp(
          config: config,
          history: history,
          assistantContent: assistantContent,
          toolCalls: toolCalls,
          toolResults: toolResults,
          enableWebSearch: enableWebSearch,
          conversationId: conversationId,
          directAnswerInstruction: directAnswerInstruction,
        );
    }
  }

  Future<String?> generateTitle({
    required ModelConfig config,
    required String userMessage,
    required String assistantMessage,
    required String conversationId,
  }) async {
    final modelName = _resolveModelName(config);
    if (modelName.isEmpty) {
      return null;
    }
    final prompt =
        '请根据以下对话内容生成一个简短的标题（不超过20个字），只输出标题内容，不要加引号或其他格式。\n\n用户：$userMessage\n助手：${assistantMessage.substring(0, math.min(assistantMessage.length, 500))}';
    try {
      if (config.apiType == ModelConfig.apiTypeAnthropic) {
        final dio = ApiClient.buildAnthropicClient(config.apiUrl);
        final requestData = {
          'model': modelName,
          'max_tokens': 100,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'stream': false,
        };
        await DebugLogManager.appendLog(
          conversationId: conversationId,
          type: 'Generate Title (Anthropic)',
          url: config.apiUrl,
          requestBody: jsonEncode(requestData),
        );
        final response = await dio.post<Map<String, dynamic>>(
          'messages',
          data: requestData,
          options: Options(
            headers: {
              'x-api-key': config.apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
          ),
        );
        await DebugLogManager.appendLog(
          conversationId: conversationId,
          type: 'Generate Title Response (Anthropic)',
          url: config.apiUrl,
          responseBody: jsonEncode(response.data ?? const {}),
        );
        final content = response.data?['content'];
        if (content is List) {
          for (final item in content) {
            if (item is Map<String, dynamic> && item['text'] != null) {
              return item['text'].toString().trim();
            }
          }
        }
        return null;
      }

      final dio = ApiClient.buildOpenAiClient(config.apiUrl);
      final requestData = {
        'model': modelName,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'stream': false,
      };
      await DebugLogManager.appendLog(
        conversationId: conversationId,
        type: 'Generate Title (OpenAI)',
        url: config.apiUrl,
        requestBody: jsonEncode(requestData),
      );
      final response = await dio.post<Map<String, dynamic>>(
        'chat/completions',
        data: requestData,
        options: Options(
          headers: {
            'authorization': 'Bearer ${config.apiKey}',
            'content-type': 'application/json',
          },
        ),
      );
      await DebugLogManager.appendLog(
        conversationId: conversationId,
        type: 'Generate Title Response (OpenAI)',
        url: config.apiUrl,
        responseBody: jsonEncode(response.data ?? const {}),
      );
      final choices = response.data?['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            return message['content']?.toString().trim();
          }
        }
      }
      return null;
    } catch (e) {
      await DebugLogManager.appendLog(
        conversationId: conversationId,
        type: 'Generate Title Error',
        url: config.apiUrl,
        responseBody: e.toString(),
        isError: true,
      );
      return null;
    }
  }

  Future<String> executeTool(ToolCall toolCall) async {
    switch (toolCall.function.name) {
      case 'search_web':
        try {
          final args = jsonDecode(toolCall.function.arguments);
          if (args is Map<String, dynamic>) {
            final query = args['query']?.toString().trim() ?? '';
            if (query.isEmpty) {
              return '搜索关键词为空';
            }
            return await searchQuery(query);
          }
          return '搜索关键词为空';
        } catch (e) {
          return '搜索执行失败: $e';
        }
      case 'fetch_webpage':
        try {
          final args = jsonDecode(toolCall.function.arguments);
          if (args is Map<String, dynamic>) {
            final url = args['url']?.toString().trim() ?? '';
            if (url.isEmpty) {
              return 'URL 为空';
            }
            return await fetchContent(url);
          }
          return 'URL 为空';
        } catch (e) {
          return '网页内容获取失败: $e';
        }
      default:
        return '未知工具: ${toolCall.function.name}';
    }
  }

  Future<String> searchQuery(String query) async {
    return _webSearchTool.searchQuery(query);
  }

  Future<String> fetchContent(String inputUrl) async {
    return _webSearchTool.fetchContent(inputUrl);
  }

  Future<Stream<ChatStreamEvent>> _streamOpenAiMessage({
    required ModelConfig config,
    required List<MessageContext> history,
    required String userMessage,
    required String? systemPrompt,
    required String? imageBase64,
    required String? mediaType,
    required bool enableWebSearch,
    required String conversationId,
  }) async {
    final dio = ApiClient.buildOpenAiClient(config.apiUrl);
    final requestData = {
      'model': _resolveModelName(config),
      'messages': _buildOpenAiMessages(
        history: history,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        imageBase64: imageBase64,
        mediaType: mediaType,
      ),
      'temperature': config.temperature,
      'stream': true,
      'stream_options': {'include_usage': true},
      if (enableWebSearch)
        'tools': _buildOpenAiWebSearchTools()
            .map((item) => item.toJson())
            .toList(),
    };
    final response = await dio.post<ResponseBody>(
      'chat/completions',
      data: requestData,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'authorization': 'Bearer ${config.apiKey}',
          'content-type': 'application/json',
        },
      ),
    );
    return _wrapStreamWithLogging(
      conversationId: conversationId,
      type: 'OpenAI Chat',
      url: config.apiUrl,
      requestJson: jsonEncode(requestData),
      originalStream: _parseOpenAiStream(response.data),
    );
  }

  Future<Stream<ChatStreamEvent>> _streamAnthropicMessage({
    required ModelConfig config,
    required List<MessageContext> history,
    required String userMessage,
    required String? systemPrompt,
    required String? imageBase64,
    required String? mediaType,
    required bool enableWebSearch,
    required String conversationId,
  }) async {
    final dio = ApiClient.buildAnthropicClient(config.apiUrl);
    final requestData = {
      'model': _resolveModelName(config),
      'max_tokens': 4096,
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        'system': systemPrompt,
      'messages': _buildAnthropicMessages(
        history: history,
        userMessage: userMessage,
        imageBase64: imageBase64,
        mediaType: mediaType,
      ),
      'temperature': config.temperature,
      'stream': true,
      if (enableWebSearch) 'tools': _buildAnthropicWebSearchTools(),
    };
    final response = await dio.post<ResponseBody>(
      'messages',
      data: requestData,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
    );
    return _wrapStreamWithLogging(
      conversationId: conversationId,
      type: 'Anthropic Chat',
      url: config.apiUrl,
      requestJson: jsonEncode(requestData),
      originalStream: _parseAnthropicStream(response.data),
    );
  }

  Future<Stream<ChatStreamEvent>> _streamOpenAiToolFollowUp({
    required ModelConfig config,
    required List<OpenAiChatMessage> history,
    required String? assistantContent,
    required List<ToolCall> toolCalls,
    required Map<String, String> toolResults,
    required bool enableWebSearch,
    required String conversationId,
    String? directAnswerInstruction,
  }) async {
    final dio = ApiClient.buildOpenAiClient(config.apiUrl);
    final messages = history.map((item) => item.toJson()).toList();
    if (directAnswerInstruction == null ||
        directAnswerInstruction.trim().isEmpty) {
      messages.add(
        OpenAiChatMessage(
          role: 'assistant',
          content: assistantContent,
          toolCalls: toolCalls,
        ).toJson(),
      );
      for (final toolCall in toolCalls) {
        messages.add(
          OpenAiChatMessage(
            role: 'tool',
            content: toolResults[toolCall.id] ?? '工具执行失败',
            toolCallId: toolCall.id,
            name: toolCall.function.name,
          ).toJson(),
        );
      }
    } else {
      for (final toolCall in toolCalls) {
        messages.add(
          OpenAiChatMessage(
            role: 'user',
            content: '[工具调用结果] ${toolResults[toolCall.id] ?? "工具执行失败"}',
          ).toJson(),
        );
      }
      messages.add(
        OpenAiChatMessage(
          role: 'system',
          content: directAnswerInstruction,
        ).toJson(),
      );
    }

    final requestData = {
      'model': _resolveModelName(config),
      'messages': messages,
      'temperature': config.temperature,
      'stream': true,
      'stream_options': {'include_usage': true},
      if (enableWebSearch)
        'tools': _buildOpenAiWebSearchTools()
            .map((item) => item.toJson())
            .toList(),
      if (!enableWebSearch) 'tool_choice': 'none',
    };
    final response = await dio.post<ResponseBody>(
      'chat/completions',
      data: requestData,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'authorization': 'Bearer ${config.apiKey}',
          'content-type': 'application/json',
        },
      ),
    );
    return _wrapStreamWithLogging(
      conversationId: conversationId,
      type: 'OpenAI Tool Follow Up',
      url: config.apiUrl,
      requestJson: jsonEncode(requestData),
      originalStream: _parseOpenAiStream(response.data),
    );
  }

  Future<Stream<ChatStreamEvent>> _streamAnthropicToolFollowUp({
    required ModelConfig config,
    required List<OpenAiChatMessage> history,
    required String? assistantContent,
    required List<ToolCall> toolCalls,
    required Map<String, String> toolResults,
    required String conversationId,
    String? directAnswerInstruction,
  }) async {
    final dio = ApiClient.buildAnthropicClient(config.apiUrl);
    final systemPrompt = _extractSystemPrompt(history);
    final messages = _convertHistoryToAnthropicMessages(history);
    if (assistantContent != null && assistantContent.trim().isNotEmpty) {
      messages.add({'role': 'assistant', 'content': assistantContent});
    }
    for (final toolCall in toolCalls) {
      messages.add({
        'role': 'user',
        'content':
            '[工具 ${toolCall.function.name} 结果]\n${toolResults[toolCall.id] ?? "工具执行失败"}',
      });
    }
    if (directAnswerInstruction != null &&
        directAnswerInstruction.trim().isNotEmpty) {
      messages.add({'role': 'user', 'content': directAnswerInstruction});
    }
    final requestData = {
      'model': _resolveModelName(config),
      'max_tokens': 4096,
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        'system': systemPrompt,
      'messages': messages,
      'temperature': config.temperature,
      'stream': true,
    };
    final response = await dio.post<ResponseBody>(
      'messages',
      data: requestData,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
    );
    return _wrapStreamWithLogging(
      conversationId: conversationId,
      type: 'Anthropic Tool Follow Up',
      url: config.apiUrl,
      requestJson: jsonEncode(requestData),
      originalStream: _parseAnthropicStream(response.data),
    );
  }

  Stream<ChatStreamEvent> _wrapStreamWithLogging({
    required String conversationId,
    required String type,
    required String url,
    required String requestJson,
    required Stream<ChatStreamEvent> originalStream,
  }) async* {
    await DebugLogManager.appendLog(
      conversationId: conversationId,
      type: type,
      url: url,
      requestBody: requestJson,
    );
    final responseBuilder = StringBuffer();
    TokenUsage? lastUsage;
    String? finishReason;
    try {
      await for (final event in originalStream) {
        switch (event) {
          case ContentDeltaEvent():
            responseBuilder.write(event.text);
          case ToolCallDeltaEvent():
            if ((event.delta.functionName ?? '').isNotEmpty) {
              responseBuilder.write('[tool_call:${event.delta.functionName}]');
            }
            if ((event.delta.arguments ?? '').isNotEmpty) {
              responseBuilder.write(event.delta.arguments);
            }
          case StreamEndEvent():
            lastUsage = event.usage;
            finishReason = event.finishReason;
            await DebugLogManager.appendLog(
              conversationId: conversationId,
              type: '$type Response',
              url: url,
              responseBody: jsonEncode({
                'content': responseBuilder.toString(),
                'usage': lastUsage == null
                    ? null
                    : {
                        'promptTokens': lastUsage.promptTokens,
                        'completionTokens': lastUsage.completionTokens,
                      },
                'finishReason': finishReason,
              }),
            );
          case StreamErrorEvent():
            await DebugLogManager.appendLog(
              conversationId: conversationId,
              type: '$type Error',
              url: url,
              responseBody: event.message,
              isError: true,
            );
        }
        yield event;
      }
    } catch (e) {
      await DebugLogManager.appendLog(
        conversationId: conversationId,
        type: '$type Error',
        url: url,
        responseBody: e.toString(),
        isError: true,
      );
      rethrow;
    }
  }

  List<Map<String, dynamic>> _buildOpenAiMessages({
    required List<MessageContext> history,
    required String userMessage,
    required String? systemPrompt,
    required String? imageBase64,
    required String? mediaType,
  }) {
    final messages = <Map<String, dynamic>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...history.map((item) => {'role': item.role, 'content': item.content}),
    ];
    final content = imageBase64 == null
        ? userMessage
        : [
            {'type': 'text', 'text': userMessage},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${mediaType ?? "image/jpeg"};base64,$imageBase64',
              },
            },
          ];
    messages.add({'role': 'user', 'content': content});
    return messages;
  }

  List<Map<String, dynamic>> _buildAnthropicMessages({
    required List<MessageContext> history,
    required String userMessage,
    required String? imageBase64,
    required String? mediaType,
  }) {
    final messages = <Map<String, dynamic>>[
      ...history.map((item) => {'role': item.role, 'content': item.content}),
    ];
    final content = imageBase64 == null
        ? userMessage
        : [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType ?? 'image/jpeg',
                'data': imageBase64,
              },
            },
            {'type': 'text', 'text': userMessage},
          ];
    messages.add({'role': 'user', 'content': content});
    return messages;
  }

  List<ToolDefinition> _buildOpenAiWebSearchTools() {
    return const [
      ToolDefinition(
        function: ToolFunctionDefinition(
          name: 'search_web',
          description: '搜索互联网获取最新信息。当需要查询实时信息、新闻、天气等时使用',
          parameters: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': '搜索关键词'},
            },
            'required': ['query'],
          },
        ),
      ),
      ToolDefinition(
        function: ToolFunctionDefinition(
          name: 'fetch_webpage',
          description: '抓取指定 URL 的网页内容。当需要读取某个网页的正文时使用',
          parameters: {
            'type': 'object',
            'properties': {
              'url': {'type': 'string', 'description': '完整的网页 URL'},
            },
            'required': ['url'],
          },
        ),
      ),
    ];
  }

  List<Map<String, dynamic>> _buildAnthropicWebSearchTools() {
    return const [
      {
        'name': 'search_web',
        'description': '搜索互联网获取最新信息。当需要查询实时信息、新闻、天气等时使用',
        'input_schema': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '搜索关键词'},
          },
          'required': ['query'],
        },
      },
      {
        'name': 'fetch_webpage',
        'description': '抓取指定 URL 的网页内容。当需要读取某个网页的正文时使用',
        'input_schema': {
          'type': 'object',
          'properties': {
            'url': {'type': 'string', 'description': '完整的网页 URL'},
          },
          'required': ['url'],
        },
      },
    ];
  }

  Stream<ChatStreamEvent> _parseOpenAiStream(ResponseBody? body) async* {
    if (body == null) {
      yield const StreamErrorEvent('空的流响应');
      return;
    }
    TokenUsage? lastUsage;
    await for (final line
        in body.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) {
        continue;
      }
      final data = line.substring(6).trim();
      if (data == '[DONE]') {
        yield StreamEndEvent(usage: lastUsage);
        break;
      }
      try {
        final json = jsonDecode(data);
        if (json is! Map<String, dynamic>) {
          continue;
        }
        final usage = json['usage'];
        if (usage is Map<String, dynamic>) {
          lastUsage = TokenUsage(
            promptTokens: _readInt(usage['prompt_tokens']),
            completionTokens: _readInt(usage['completion_tokens']),
          );
        }
        final choices = json['choices'];
        if (choices is! List || choices.isEmpty) {
          continue;
        }
        final first = choices.first;
        if (first is! Map<String, dynamic>) {
          continue;
        }
        final delta = first['delta'];
        if (delta is Map<String, dynamic>) {
          final content = delta['content']?.toString();
          if (content != null && content.isNotEmpty) {
            yield ContentDeltaEvent(content);
          }
          final toolCalls = delta['tool_calls'];
          if (toolCalls is List) {
            for (final entry in toolCalls) {
              if (entry is Map<String, dynamic>) {
                final function = entry['function'];
                yield ToolCallDeltaEvent(
                  ToolCallDelta(
                    index: _readInt(entry['index']),
                    id: entry['id']?.toString(),
                    functionName: function is Map<String, dynamic>
                        ? function['name']?.toString()
                        : null,
                    arguments: function is Map<String, dynamic>
                        ? function['arguments']?.toString()
                        : null,
                  ),
                );
              }
            }
          }
        }
        final finishReason = first['finish_reason']?.toString();
        if (finishReason != null && finishReason != 'stop') {
          yield StreamEndEvent(usage: lastUsage, finishReason: finishReason);
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Stream<ChatStreamEvent> _parseAnthropicStream(ResponseBody? body) async* {
    if (body == null) {
      yield const StreamErrorEvent('空的流响应');
      return;
    }
    TokenUsage? lastUsage;
    await for (final line
        in body.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) {
        continue;
      }
      final data = line.substring(6).trim();
      if (data.isEmpty) {
        continue;
      }
      try {
        final json = jsonDecode(data);
        if (json is! Map<String, dynamic>) {
          continue;
        }
        final type = json['type']?.toString() ?? '';
        switch (type) {
          case 'content_block_delta':
            final delta = json['delta'];
            if (delta is Map<String, dynamic>) {
              if ((delta['type']?.toString() ?? '') == 'text_delta') {
                final text = delta['text']?.toString() ?? '';
                if (text.isNotEmpty) {
                  yield ContentDeltaEvent(text);
                }
              } else if ((delta['type']?.toString() ?? '') ==
                  'input_json_delta') {
                final partial = delta['partial_json']?.toString();
                if (partial != null && partial.isNotEmpty) {
                  yield ToolCallDeltaEvent(
                    ToolCallDelta(
                      index: _readInt(json['index']),
                      arguments: partial,
                    ),
                  );
                }
              }
            }
          case 'content_block_start':
            final contentBlock = json['content_block'];
            if (contentBlock is Map<String, dynamic> &&
                contentBlock['type']?.toString() == 'tool_use') {
              yield ToolCallDeltaEvent(
                ToolCallDelta(
                  index: _readInt(json['index']),
                  id: contentBlock['id']?.toString(),
                  functionName: contentBlock['name']?.toString(),
                ),
              );
            }
          case 'message_delta':
            final usage = json['usage'];
            if (usage is Map<String, dynamic>) {
              lastUsage = TokenUsage(
                promptTokens: _readInt(usage['input_tokens']),
                completionTokens: _readInt(usage['output_tokens']),
              );
            }
          case 'message_stop':
            yield StreamEndEvent(usage: lastUsage);
            break;
          default:
            break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  String _resolveModelName(ModelConfig config) {
    final defaultModel = (config.defaultModel ?? '').trim();
    if (defaultModel.isNotEmpty) {
      return defaultModel;
    }
    if (config.models.isNotEmpty) {
      return config.models.first.trim();
    }
    return '';
  }

  String? _extractSystemPrompt(List<OpenAiChatMessage> history) {
    for (final item in history) {
      if (item.role == 'system') {
        return item.content?.toString();
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _convertHistoryToAnthropicMessages(
    List<OpenAiChatMessage> history,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final item in history) {
      if (item.role == 'system') {
        continue;
      }
      final content = item.content;
      if (content == null) {
        continue;
      }
      result.add({
        'role': item.role == 'tool' ? 'user' : item.role,
        'content': content.toString(),
      });
    }
    return result;
  }
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
