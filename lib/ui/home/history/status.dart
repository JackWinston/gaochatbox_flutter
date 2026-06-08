import 'package:get/get.dart';

import '../../chat/models.dart';

class HistoryState {
  final RxBool isLoading = true.obs;
  final RxString keyword = ''.obs;
  final RxnString activeFilter = RxnString();
  final RxList<String> tags = <String>[].obs;
  final RxList<ChatConversationHistoryItem> conversations =
      <ChatConversationHistoryItem>[].obs;
}
