import 'package:get/get.dart';

import '../../data/model/model_config.dart';
import 'models.dart';

class ChatState {
  final RxString systemPrompt = ''.obs;
  final RxString promptTag = ''.obs;
  final RxString conversationId = ''.obs;
  final RxString title = ''.obs;
  final RxString selectedModelName = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isStreaming = false.obs;
  final RxBool webSearchEnabled = false.obs;
  final RxBool hasPendingAttachment = false.obs;
  final RxInt maxToolCallRounds = 8.obs;
  final RxnString contextCompressionHint = RxnString();
  final Rx<PendingResponsePhase> pendingResponsePhase =
      PendingResponsePhase.idle.obs;
  final Rx<ChatRenderSettings> renderSettings =
      const ChatRenderSettings().obs;
  final Rx<ChatContextUsageInfo> contextUsage =
      const ChatContextUsageInfo().obs;
  final RxList<ChatItem> chatItems = <ChatItem>[].obs;
  final RxList<ModelConfig> modelConfigs = <ModelConfig>[].obs;
}
