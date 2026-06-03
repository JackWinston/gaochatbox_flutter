import 'package:get/get.dart';
import '../../../data/model/system_prompt.dart';

class QuickStartState {
  final RxList<SystemPrompt> prompts = <SystemPrompt>[].obs;
  final RxBool isLoading = true.obs;
  final RxInt dragOverIndex = (-1).obs;
}
