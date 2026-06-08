import 'package:get/get.dart';

import '../../../app_settings_service.dart';
import '../../../data/model/model_config.dart';
import '../../../data/repository/settings_repository.dart';
import '../../../data/remote/anthropic_api.dart';
import '../../../data/remote/openai_api.dart';
import '../../../util/model_config_manager.dart';
import '../../../util/model_context_limit_resolver.dart';
import 'status.dart';

class SettingsLogic extends GetxController {
  final SettingsState state = SettingsState();

  final ModelConfigManager _modelConfigManager = ModelConfigManager();
  final ModelContextLimitResolver _contextLimitResolver =
      ModelContextLimitResolver();
  final AppSettingsService _appSettingsService = Get.find<AppSettingsService>();

  late final SettingsRepository _repository;
  late final Worker _themeWorker;
  late final Worker _languageWorker;

  @override
  void onInit() {
    super.onInit();
    _repository = _appSettingsService.repository;
    _themeWorker = ever<String>(
      _appSettingsService.currentTheme,
      (value) => state.currentTheme.value = value,
    );
    _languageWorker = ever<String>(
      _appSettingsService.currentLanguage,
      (value) => state.currentLanguage.value = value,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    state.isLoading.value = true;
    await _modelConfigManager.init();
    await refreshModels();
    final settings = await _repository.load();
    state.showCharCount.value = settings.showCharCount;
    state.showTokenCount.value = settings.showTokenCount;
    state.showModelName.value = settings.showModelName;
    state.showTimestamp.value = settings.showTimestamp;
    state.webSearchEnabled.value = settings.webSearchEnabled;
    state.maxToolCallRounds.value = settings.maxToolCallRounds;
    state.currentTheme.value = settings.theme;
    state.currentLanguage.value = settings.language;
    state.isLoading.value = false;
  }

  Future<void> refreshModels() async {
    state.models.assignAll(await _modelConfigManager.getAll());
  }

  Future<void> addModel(ModelConfig model) async {
    await _modelConfigManager.add(model);
    await refreshModels();
  }

  Future<void> updateModel(ModelConfig model) async {
    await _modelConfigManager.update(model);
    await refreshModels();
  }

  Future<void> deleteModel(String id) async {
    await _modelConfigManager.delete(id);
    await refreshModels();
  }

  Future<void> setShowCharCount(bool value) async {
    state.showCharCount.value = value;
    await _repository.setShowCharCount(value);
  }

  Future<void> setShowTokenCount(bool value) async {
    state.showTokenCount.value = value;
    await _repository.setShowTokenCount(value);
  }

  Future<void> setShowModelName(bool value) async {
    state.showModelName.value = value;
    await _repository.setShowModelName(value);
  }

  Future<void> setShowTimestamp(bool value) async {
    state.showTimestamp.value = value;
    await _repository.setShowTimestamp(value);
  }

  Future<void> setWebSearchEnabled(bool value) async {
    state.webSearchEnabled.value = value;
    await _repository.setWebSearchEnabled(value);
  }

  Future<void> setMaxToolCallRounds(int value) async {
    final rounds = value.clamp(
      SettingsRepository.minMaxToolCallRounds,
      SettingsRepository.maxMaxToolCallRounds,
    );
    state.maxToolCallRounds.value = rounds;
    await _repository.setMaxToolCallRounds(rounds);
  }

  Future<void> setTheme(String value) async {
    await _appSettingsService.setTheme(value);
  }

  Future<void> setLanguage(String value) async {
    await _appSettingsService.setLanguage(value);
  }

  Future<List<String>> fetchModels({
    required String apiType,
    required String apiUrl,
    required String apiKey,
  }) async {
    if (apiType == ModelConfig.apiTypeAnthropic) {
      final response = await AnthropicApi(apiUrl).getModels(apiKey);
      final models =
          response.data
              .map((item) => item.id)
              .where((item) => item.isNotEmpty)
              .toList()
            ..sort();
      return models;
    }

    final response = await OpenAiApi(apiUrl).getModels(apiKey);
    final models =
        response.data
            .map((item) => item.id)
            .where((item) => item.isNotEmpty)
            .toList()
          ..sort();
    return models;
  }

  Future<int> resolveContextLimit({
    required String apiType,
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) {
    return _contextLimitResolver.resolve(
      apiType: apiType,
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
    );
  }

  int? resolveContextLimitStatic({
    required String apiType,
    required String modelName,
  }) {
    return _contextLimitResolver.resolveStatic(
      apiType: apiType,
      modelName: modelName,
    );
  }

  void toggleModelSection() {
    state.modelSectionExpanded.toggle();
  }

  void toggleUiSection() {
    state.uiSectionExpanded.toggle();
  }

  void toggleCapabilitySection() {
    state.capabilitySectionExpanded.toggle();
  }

  @override
  void onClose() {
    _themeWorker.dispose();
    _languageWorker.dispose();
    super.onClose();
  }
}
