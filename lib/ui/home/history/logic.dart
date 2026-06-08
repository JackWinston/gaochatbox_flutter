import 'package:get/get.dart';

import '../../chat/conversation_store.dart';
import '../../../util/debug_log_manager.dart';
import 'status.dart';

class HistoryLogic extends GetxController {
  final HistoryState state = HistoryState();
  final ChatConversationStore _store = ChatConversationStore();

  @override
  void onInit() {
    super.onInit();
    refreshHistory();
  }

  Future<void> refreshHistory() async {
    state.isLoading.value = true;
    final tags = await _store.getConversationTags();
    final conversations = await _store.getConversationHistory(
      keyword: state.keyword.value,
      tag: state.activeFilter.value,
    );
    state.tags.assignAll(tags);
    state.conversations.assignAll(conversations);
    state.isLoading.value = false;
  }

  Future<void> setKeyword(String value) async {
    final next = value.trim();
    if (state.keyword.value == next) {
      return;
    }
    state.keyword.value = next;
    await refreshHistory();
  }

  Future<void> setFilter(String? value) async {
    final next = value?.trim();
    state.activeFilter.value = (next == null || next.isEmpty) ? null : next;
    await refreshHistory();
  }

  Future<void> clearFilter() async {
    if (state.activeFilter.value == null) {
      return;
    }
    state.activeFilter.value = null;
    await refreshHistory();
  }

  Future<void> deleteConversation(String conversationId) async {
    await _store.deleteConversation(conversationId);
    await DebugLogManager.deleteLogFile(conversationId);
    await refreshHistory();
  }
}
