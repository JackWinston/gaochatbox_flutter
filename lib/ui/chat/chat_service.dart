import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../data/model/model_config.dart';
import '../../data/remote/api_client.dart';
import 'models.dart';

class ChatService {
  ChatService();

  Future<Stream<ChatStreamEvent>> streamMessage({
    required ModelConfig config,
    required List<MessageContext> history,
    required String userMessage,
    required String? systemPrompt,
    required String? imageBase64,
    required String? mediaType,
    required bool enableWebSearch,
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
          directAnswerInstruction: directAnswerInstruction,
        );
    }
  }

  Future<String?> generateTitle({
    required ModelConfig config,
    required String userMessage,
    required String assistantMessage,
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
        final response = await dio.post<Map<String, dynamic>>(
          'messages',
          data: {
            'model': modelName,
            'max_tokens': 100,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.7,
            'stream': false,
          },
          options: Options(
            headers: {
              'x-api-key': config.apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
          ),
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
      final response = await dio.post<Map<String, dynamic>>(
        'chat/completions',
        data: {
          'model': modelName,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'stream': false,
        },
        options: Options(
          headers: {
            'authorization': 'Bearer ${config.apiKey}',
            'content-type': 'application/json',
          },
        ),
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
    } catch (_) {
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
    try {
      final bing = await _searchBing(query);
      if (bing.isNotEmpty) {
        return _formatSearchResults(query, bing);
      }
    } catch (_) {}
    try {
      final ddg = await _searchDuckDuckGo(query);
      if (ddg.isNotEmpty) {
        return _formatSearchResults(query, ddg);
      }
      return '未找到与"$query"相关的搜索结果';
    } catch (_) {
      return '搜索失败: 网络超时或搜索服务暂时不可用，请稍后重试';
    }
  }

  Future<String> fetchContent(String inputUrl) async {
    try {
      final url = _normalizeUrl(inputUrl);
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          responseType: ResponseType.plain,
          followRedirects: true,
        ),
      );
      final response = await dio.get<String>(
        url,
        options: Options(headers: _browserHeaders(url)),
      );
      final body = response.data?.trim() ?? '';
      final title = _extractTitle(body);
      final content = _extractReadableContent(body);
      return [
        '以下是 $url 的网页内容：',
        if (title.isNotEmpty) '标题: $title',
        '',
        content,
      ].join('\n').trim();
    } catch (e) {
      return '网页内容获取失败: $e';
    }
  }

  Future<Stream<ChatStreamEvent>> _streamOpenAiMessage({
    required ModelConfig config,
    required List<MessageContext> history,
    required String userMessage,
    required String? systemPrompt,
    required String? imageBase64,
    required String? mediaType,
    required bool enableWebSearch,
  }) async {
    final dio = ApiClient.buildOpenAiClient(config.apiUrl);
    final response = await dio.post<ResponseBody>(
      'chat/completions',
      data: {
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
          'tools': _buildOpenAiWebSearchTools().map((item) => item.toJson()).toList(),
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'authorization': 'Bearer ${config.apiKey}',
          'content-type': 'application/json',
        },
      ),
    );
    return _parseOpenAiStream(response.data);
  }

  Future<Stream<ChatStreamEvent>> _streamAnthropicMessage({
    required ModelConfig config,
    required List<MessageContext> history,
    required String userMessage,
    required String? systemPrompt,
    required String? imageBase64,
    required String? mediaType,
    required bool enableWebSearch,
  }) async {
    final dio = ApiClient.buildAnthropicClient(config.apiUrl);
    final response = await dio.post<ResponseBody>(
      'messages',
      data: {
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
        if (enableWebSearch)
          'tools': _buildAnthropicWebSearchTools(),
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
    );
    return _parseAnthropicStream(response.data);
  }

  Future<Stream<ChatStreamEvent>> _streamOpenAiToolFollowUp({
    required ModelConfig config,
    required List<OpenAiChatMessage> history,
    required String? assistantContent,
    required List<ToolCall> toolCalls,
    required Map<String, String> toolResults,
    required bool enableWebSearch,
    String? directAnswerInstruction,
  }) async {
    final dio = ApiClient.buildOpenAiClient(config.apiUrl);
    final messages = history.map((item) => item.toJson()).toList();
    if (directAnswerInstruction == null || directAnswerInstruction.trim().isEmpty) {
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

    final response = await dio.post<ResponseBody>(
      'chat/completions',
      data: {
        'model': _resolveModelName(config),
        'messages': messages,
        'temperature': config.temperature,
        'stream': true,
        'stream_options': {'include_usage': true},
        if (enableWebSearch)
          'tools': _buildOpenAiWebSearchTools().map((item) => item.toJson()).toList(),
        if (!(enableWebSearch)) 'tool_choice': 'none',
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'authorization': 'Bearer ${config.apiKey}',
          'content-type': 'application/json',
        },
      ),
    );
    return _parseOpenAiStream(response.data);
  }

  Future<Stream<ChatStreamEvent>> _streamAnthropicToolFollowUp({
    required ModelConfig config,
    required List<OpenAiChatMessage> history,
    required String? assistantContent,
    required List<ToolCall> toolCalls,
    required Map<String, String> toolResults,
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
        'content': '[工具 ${toolCall.function.name} 结果]\n${toolResults[toolCall.id] ?? "工具执行失败"}',
      });
    }
    if (directAnswerInstruction != null && directAnswerInstruction.trim().isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': directAnswerInstruction,
      });
    }
    final response = await dio.post<ResponseBody>(
      'messages',
      data: {
        'model': _resolveModelName(config),
        'max_tokens': 4096,
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
          'system': systemPrompt,
        'messages': messages,
        'temperature': config.temperature,
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
    );
    return _parseAnthropicStream(response.data);
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
              'query': {
                'type': 'string',
                'description': '搜索关键词',
              },
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
              'url': {
                'type': 'string',
                'description': '完整的网页 URL',
              },
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
            'query': {
              'type': 'string',
              'description': '搜索关键词',
            },
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
            'url': {
              'type': 'string',
              'description': '完整的网页 URL',
            },
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
    await for (final line in body.stream
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
          yield StreamEndEvent(
            usage: lastUsage,
            finishReason: finishReason,
          );
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
    await for (final line in body.stream
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
              } else if ((delta['type']?.toString() ?? '') == 'input_json_delta') {
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

  Future<List<_SearchResult>> _searchDuckDuckGo(String query) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
      ),
    );
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = 'https://html.duckduckgo.com/html/?q=$encodedQuery';
    final response = await dio.get<String>(
      url,
      options: Options(headers: _browserHeaders(url)),
    );
    return _parseDuckDuckGoHtml(response.data ?? '');
  }

  Future<List<_SearchResult>> _searchBing(String query) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
      ),
    );
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = 'https://www.bing.com/search?q=$encodedQuery&setlang=zh-Hans';
    final response = await dio.get<String>(
      url,
      options: Options(headers: _browserHeaders(url)),
    );
    return _parseBingHtml(response.data ?? '');
  }

  String _formatSearchResults(String query, List<_SearchResult> results) {
    if (results.isEmpty) {
      return '未找到与"$query"相关的搜索结果';
    }
    final buffer = StringBuffer('以下是"$query"的搜索结果：\n\n');
    for (var index = 0; index < results.length; index++) {
      final item = results[index];
      buffer
        ..writeln('${index + 1}. ${item.title}')
        ..writeln('   链接: ${item.url}')
        ..writeln('   摘要: ${item.snippet}')
        ..writeln();
    }
    return buffer.toString().trim();
  }

  List<_SearchResult> _parseDuckDuckGoHtml(String html) {
    final anchorRegex = RegExp(
      '<a[^>]+class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final snippetRegex = RegExp(
      '<a[^>]+class="result__snippet"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final anchors = anchorRegex.allMatches(html).toList();
    final snippets = snippetRegex.allMatches(html).toList();
    final results = <_SearchResult>[];
    for (var index = 0; index < anchors.length && results.length < 10; index++) {
      final match = anchors[index];
      final rawUrl = match.group(1) ?? '';
      final rawTitle = match.group(2) ?? '';
      final snippet = index < snippets.length ? _stripHtml(snippets[index].group(1) ?? '') : '';
      final title = _stripHtml(rawTitle);
      final url = _extractRedirectUrl(rawUrl);
      if (title.isNotEmpty && url.isNotEmpty) {
        results.add(_SearchResult(title: title, url: url, snippet: snippet));
      }
    }
    return results;
  }

  List<_SearchResult> _parseBingHtml(String html) {
    final blockRegex = RegExp(
      '<li[^>]+class="[^"]*\\bb_algo\\b[^"]*"[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    final insideAnchorRegex = RegExp(
      '<a[^>]*href="([^"]+)"[^>]*>\\s*<h2[^>]*>(.*?)</h2>\\s*</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final outsideAnchorRegex = RegExp(
      '<h2[^>]*>\\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>\\s*</h2>',
      caseSensitive: false,
      dotAll: true,
    );
    final snippetRegex = RegExp('<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true);
    final results = <_SearchResult>[];
    for (final blockMatch in blockRegex.allMatches(html)) {
      if (results.length >= 10) {
        break;
      }
      final block = blockMatch.group(1) ?? '';
      final titleMatch = insideAnchorRegex.firstMatch(block) ?? outsideAnchorRegex.firstMatch(block);
      if (titleMatch == null) {
        continue;
      }
      final url = _stripHtml(titleMatch.group(1) ?? '');
      final title = _stripHtml(titleMatch.group(2) ?? '');
      final snippet = _stripHtml(snippetRegex.firstMatch(block)?.group(1) ?? '');
      if (title.isNotEmpty && url.isNotEmpty) {
        results.add(_SearchResult(title: title, url: url, snippet: snippet));
      }
    }
    return results;
  }

  String _extractRedirectUrl(String rawUrl) {
    final uddg = RegExp('uddg=([^&]+)').firstMatch(rawUrl)?.group(1);
    return uddg == null ? rawUrl : Uri.decodeComponent(uddg);
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String _extractTitle(String html) {
    final match = RegExp(
      '<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return _stripHtml(match?.group(1) ?? '');
  }

  String _extractReadableContent(String body) {
    final normalized = body.trim();
    if (normalized.isEmpty) {
      return '网页内容为空';
    }
    if (!normalized.toLowerCase().contains('<html') &&
        !normalized.toLowerCase().contains('<body')) {
      return normalized.substring(0, math.min(normalized.length, 6000));
    }
    final withoutScripts = normalized
        .replaceAll(
          RegExp(
            '<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            '<style[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            '<noscript[^>]*>.*?</noscript>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        );
    final text = _stripHtml(withoutScripts).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      return '未提取到可读正文';
    }
    return text.substring(0, math.min(text.length, 6000));
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp('<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  Map<String, String> _browserHeaders(String url) {
    final uri = Uri.tryParse(url);
    final referer = uri == null ? 'https://www.google.com/' : '${uri.scheme}://${uri.host}/';
    return {
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'referer': referer,
    };
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

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;
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
