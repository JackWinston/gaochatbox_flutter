import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class ChatConversationStore {
  static const _keyConversationSummaries = 'chat_conversation_summaries';
  static const _messagePrefix = 'chat_conversation_messages_';
  static const _uuid = Uuid();

  Future<List<ChatConversationSummary>> getConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyConversationSummaries);
    if (json == null || json.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatConversationSummary.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  Future<ChatConversationSummary?> getConversation(String id) async {
    final conversations = await getConversations();
    for (final conversation in conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  Future<List<StoredChatMessage>> getMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_messagePrefix$conversationId');
    if (json == null || json.isEmpty) {
      return [];
    }
    try {
      final messages = StoredChatMessage.listFromJson(json);
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    } catch (_) {
      return [];
    }
  }

  Future<ChatConversationSummary> ensureConversation({
    String? conversationId,
    required String fallbackTitle,
    required String systemPromptContent,
    required String systemPromptTag,
    required String displayTag,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = await getConversations();
    if (conversationId != null && conversationId.isNotEmpty) {
      final index = list.indexWhere((item) => item.id == conversationId);
      if (index >= 0) {
        final updated = list[index].copyWith(
          updatedAt: now,
          systemPromptContent: systemPromptContent,
          systemPromptTag: systemPromptTag,
          displayTag: displayTag,
        );
        list[index] = updated;
        await _saveConversations(list, prefs);
        return updated;
      }
    }

    final created = ChatConversationSummary(
      id: _uuid.v4(),
      title: fallbackTitle,
      systemPromptContent: systemPromptContent,
      systemPromptTag: systemPromptTag,
      displayTag: displayTag,
      createdAt: now,
      updatedAt: now,
    );
    list.add(created);
    await _saveConversations(list, prefs);
    await prefs.setString(
      '$_messagePrefix${created.id}',
      StoredChatMessage.listToJson(const []),
    );
    return created;
  }

  Future<String> addUserMessage({
    required String conversationId,
    required String content,
    required String? displayContent,
    required String? attachmentName,
    required String? imageUri,
  }) async {
    final message = StoredChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: content,
      displayContent: displayContent,
      attachmentName: attachmentName,
      imageUri: imageUri,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _appendMessage(conversationId, message);
    return message.id;
  }

  Future<String> addAssistantMessage({
    required String conversationId,
    required String content,
    required String? modelName,
    required bool isStreaming,
  }) async {
    final message = StoredChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: content,
      modelName: modelName,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      isStreaming: isStreaming,
    );
    await _appendMessage(conversationId, message);
    return message.id;
  }

  Future<void> finishStreamingMessage({
    required String conversationId,
    required String messageId,
    required String content,
    required int tokenCount,
  }) async {
    final messages = await getMessages(conversationId);
    final index = messages.indexWhere((item) => item.id == messageId);
    if (index < 0) {
      return;
    }
    messages[index] = messages[index].copyWith(
      content: content,
      tokenCount: tokenCount,
      isStreaming: false,
    );
    await _saveMessages(conversationId, messages);
    await _touchConversation(conversationId);
  }

  Future<void> addToolCallMessage({
    required String conversationId,
    required String assistantContent,
    required String toolCallsJson,
    required String? modelName,
  }) async {
    final message = StoredChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: assistantContent,
      modelName: modelName,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      toolCallsJson: toolCallsJson,
    );
    await _appendMessage(conversationId, message);
  }

  Future<void> addToolResultMessage({
    required String conversationId,
    required String toolCallId,
    required String content,
    required String? name,
  }) async {
    final message = StoredChatMessage(
      id: _uuid.v4(),
      role: 'tool',
      content: content,
      toolCallId: toolCallId,
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _appendMessage(conversationId, message);
  }

  Future<void> updateConversationTitle({
    required String conversationId,
    required String title,
    String? displayTag,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getConversations();
    final index = list.indexWhere((item) => item.id == conversationId);
    if (index < 0) {
      return;
    }
    list[index] = list[index].copyWith(
      title: title,
      displayTag: displayTag ?? title,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveConversations(list, prefs);
  }

  Future<void> deleteConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getConversations();
    list.removeWhere((item) => item.id == conversationId);
    await _saveConversations(list, prefs);
    await prefs.remove('$_messagePrefix$conversationId');
  }

  Future<int> getTotalTokens(String conversationId) async {
    final messages = await getMessages(conversationId);
    return messages.fold<int>(
      0,
      (sum, item) => sum + item.tokenCount,
    );
  }

  Future<void> replaceMessages(
    String conversationId,
    List<StoredChatMessage> messages,
  ) async {
    await _saveMessages(conversationId, messages);
    await _touchConversation(conversationId);
  }

  Future<void> _appendMessage(
    String conversationId,
    StoredChatMessage message,
  ) async {
    final messages = await getMessages(conversationId);
    messages.add(message);
    await _saveMessages(conversationId, messages);
    await _touchConversation(conversationId);
  }

  Future<void> _touchConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getConversations();
    final index = list.indexWhere((item) => item.id == conversationId);
    if (index < 0) {
      return;
    }
    list[index] = list[index].copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveConversations(list, prefs);
  }

  Future<void> _saveMessages(
    String conversationId,
    List<StoredChatMessage> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_messagePrefix$conversationId',
      StoredChatMessage.listToJson(messages),
    );
  }

  Future<void> _saveConversations(
    List<ChatConversationSummary> conversations,
    SharedPreferences prefs,
  ) async {
    final sorted = [...conversations]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _keyConversationSummaries,
      jsonEncode(sorted.map((item) => item.toJson()).toList()),
    );
  }
}
