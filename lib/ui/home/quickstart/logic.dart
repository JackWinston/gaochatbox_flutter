import 'package:get/get.dart';
import '../../../data/model/system_prompt.dart';
import '../../../util/system_prompt_manager.dart';
import 'status.dart';

class QuickStartLogic extends GetxController {
  final QuickStartState state = QuickStartState();
  final _manager = SystemPromptManager();

  @override
  void onInit() {
    super.onInit();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    state.isLoading.value = true;
    await _manager.init();
    state.prompts.assignAll(await _manager.getAll());
    state.isLoading.value = false;
  }

  Future<void> refreshPrompts() async {
    state.prompts.assignAll(await _manager.getAll());
  }

  Future<void> addPrompt(String tag, String content) async {
    final prompt = SystemPrompt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      tag: tag,
    );
    await _manager.add(prompt);
    await refreshPrompts();
  }

  Future<void> updatePrompt(SystemPrompt prompt) async {
    await _manager.update(prompt);
    await refreshPrompts();
  }

  Future<void> deletePrompt(SystemPrompt prompt) async {
    await _manager.delete(prompt.id);
    await refreshPrompts();
  }

  Future<void> reorderPrompts(List<SystemPrompt> orderedPrompts) async {
    await _manager.reorderPrompts(orderedPrompts);
    await refreshPrompts();
  }

  void onPromptTap(SystemPrompt prompt) {
    // TODO: navigate to chat page
  }

  void updateDragOverIndex(int index) {
    state.dragOverIndex.value = index;
  }
}
