import 'package:get/get.dart';
import 'status.dart';

class ChatLogic extends GetxController {
  final ChatState state = ChatState();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      state.promptTag.value = args['tag'] ?? '';
      state.systemPrompt.value = args['content'] ?? '';
    }
  }
}
