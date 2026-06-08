import 'package:get/get.dart';

import '../../../data/model/model_config.dart';
import '../../../data/repository/settings_repository.dart';

class SettingsState {
  final RxBool isLoading = true.obs;

  final RxList<ModelConfig> models = <ModelConfig>[].obs;

  final RxBool modelSectionExpanded = true.obs;
  final RxBool uiSectionExpanded = false.obs;
  final RxBool capabilitySectionExpanded = false.obs;

  final RxBool showCharCount = false.obs;
  final RxBool showTokenCount = false.obs;
  final RxBool showModelName = false.obs;
  final RxBool showTimestamp = false.obs;
  final RxBool webSearchEnabled = false.obs;

  final RxInt maxToolCallRounds =
      SettingsRepository.defaultMaxToolCallRounds.obs;
  final RxString currentLanguage = 'system'.obs;
  final RxString currentTheme = 'system'.obs;
}
