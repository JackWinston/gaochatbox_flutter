import 'package:get/get.dart';

import '../../../app_settings_service.dart';
import '../../../data/model/system_prompt.dart';
import '../../../util/system_prompt_manager.dart';
import '../../chat/view.dart';
import 'status.dart';

class QuickStartLogic extends GetxController {
  final QuickStartState state = QuickStartState();
  final _manager = SystemPromptManager();
  final AppSettingsService _appSettingsService = Get.find<AppSettingsService>();

  late final Worker _languageWorker;

  @override
  void onInit() {
    super.onInit();
    _loadPrompts();
    _languageWorker = ever<String>(_appSettingsService.currentLanguage, (_) async {
      await _manager.init();
      await refreshPrompts();
    });
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
    Get.to(
      () => const ChatPage(),
      arguments: {
        'tag': prompt.tag,
        'content': prompt.content,
      },
    );
  }

  void updateDragOverIndex(int index) {
    state.dragOverIndex.value = index;
  }

  @override
  void onClose() {
    _languageWorker.dispose();
    super.onClose();
  }
}
