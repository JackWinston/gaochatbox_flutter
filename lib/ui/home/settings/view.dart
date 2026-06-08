import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../data/model/model_config.dart';
import '../../../data/repository/settings_repository.dart';
import 'logic.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final SettingsLogic logic = Get.put(SettingsLogic());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr)),
      body: Obx(() {
        if (logic.state.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              context: context,
              theme: theme,
              title: 'settings.section.model.title'.tr,
              subtitle: 'settings.section.model.subtitle'.tr,
              expanded: logic.state.modelSectionExpanded.value,
              onTap: logic.toggleModelSection,
              child: Column(
                children: [
                  ...logic.state.models.map(
                    (model) => _buildModelTile(context, theme, model),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showModelDialog(context),
                      icon: const Icon(Icons.add),
                      label: Text('settings.add_model'.tr),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context: context,
              theme: theme,
              title: 'settings.section.ui.title'.tr,
              subtitle: 'settings.section.ui.subtitle'.tr,
              expanded: logic.state.uiSectionExpanded.value,
              onTap: logic.toggleUiSection,
              child: Column(
                children: [
                  _buildActionTile(
                    context: context,
                    title: 'settings.theme'.tr,
                    value: _themeLabel(logic.state.currentTheme.value),
                    onTap: () => _showThemeDialog(context),
                  ),
                  _buildActionTile(
                    context: context,
                    title: 'settings.language'.tr,
                    value: _languageLabel(logic.state.currentLanguage.value),
                    onTap: () => _showLanguageDialog(context),
                  ),
                  _buildSwitchTile(
                    title: 'settings.show_char_count'.tr,
                    value: logic.state.showCharCount.value,
                    onChanged: logic.setShowCharCount,
                  ),
                  _buildSwitchTile(
                    title: 'settings.show_token_count'.tr,
                    value: logic.state.showTokenCount.value,
                    onChanged: logic.setShowTokenCount,
                  ),
                  _buildSwitchTile(
                    title: 'settings.show_model_name'.tr,
                    value: logic.state.showModelName.value,
                    onChanged: logic.setShowModelName,
                  ),
                  _buildSwitchTile(
                    title: 'settings.show_timestamp'.tr,
                    value: logic.state.showTimestamp.value,
                    onChanged: logic.setShowTimestamp,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context: context,
              theme: theme,
              title: 'settings.section.capability.title'.tr,
              subtitle: 'settings.section.capability.subtitle'.tr,
              expanded: logic.state.capabilitySectionExpanded.value,
              onTap: logic.toggleCapabilitySection,
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'settings.enable_web_search'.tr,
                    value: logic.state.webSearchEnabled.value,
                    onChanged: logic.setWebSearchEnabled,
                  ),
                  _buildActionTile(
                    context: context,
                    title: 'settings.max_tool_call_rounds'.tr,
                    value: '${logic.state.maxToolCallRounds.value}',
                    onTap: () => _showMaxToolCallRoundsDialog(context),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildModelTile(
    BuildContext context,
    ThemeData theme,
    ModelConfig model,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                model.tag,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (model.isDefault)
              Chip(
                label: Text('common.default'.tr),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide.none,
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.model.api_type'.trParams({'value': model.apiType}),
              ),
              if ((model.defaultModel ?? '').isNotEmpty)
                Text(
                  'settings.model.default_model'.trParams({
                    'value': model.defaultModel ?? '',
                  }),
                ),
              if (model.apiUrl.isNotEmpty)
                Text(
                  'settings.model.api_url'.trParams({'value': model.apiUrl}),
                ),
              Text(
                'settings.model.temperature'.trParams({
                  'value': model.temperature.toStringAsFixed(2),
                }),
              ),
            ],
          ),
        ),
        onTap: () => _showModelDialog(context, model: model),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showModelDialog(context, model: model);
            } else if (value == 'delete') {
              _showDeleteModelConfirm(context, model);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(value: 'edit', child: Text('common.edit'.tr)),
            PopupMenuItem<String>(
              value: 'delete',
              child: Text('common.delete'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _showDeleteModelConfirm(
    BuildContext context,
    ModelConfig model,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.model.delete_title'.tr),
        content: Text(
          'settings.model.delete_message'.trParams({'name': model.tag}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('common.delete'.tr),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await logic.deleteModel(model.id);
    }
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('settings.dialog.select_theme'.tr),
        children: [
          _buildChoiceOption(context, 'system', 'settings.theme.system'.tr),
          _buildChoiceOption(context, 'light', 'settings.theme.light'.tr),
          _buildChoiceOption(context, 'dark', 'settings.theme.dark'.tr),
        ],
      ),
    );
    if (value != null) {
      await logic.setTheme(value);
    }
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('settings.dialog.select_language'.tr),
        children: [
          _buildChoiceOption(context, 'system', 'settings.language.system'.tr),
          _buildChoiceOption(context, 'zh', 'settings.language.zh'.tr),
          _buildChoiceOption(context, 'en', 'settings.language.en'.tr),
        ],
      ),
    );
    if (value != null) {
      await logic.setLanguage(value);
    }
  }

  Widget _buildChoiceOption(BuildContext context, String value, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value),
      child: Text(label),
    );
  }

  Future<void> _showMaxToolCallRoundsDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: logic.state.maxToolCallRounds.value.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.dialog.max_tool_call_rounds'.tr),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText:
                '${SettingsRepository.minMaxToolCallRounds}-${SettingsRepository.maxMaxToolCallRounds}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(int.tryParse(controller.text.trim()));
            },
            child: Text('common.confirm'.tr),
          ),
        ],
      ),
    );

    if (result == null) {
      return;
    }

    if (result < SettingsRepository.minMaxToolCallRounds ||
        result > SettingsRepository.maxMaxToolCallRounds) {
      Get.snackbar(
        'settings.snackbar.invalid_input'.tr,
        'settings.snackbar.invalid_rounds'.trParams({
          'min': '${SettingsRepository.minMaxToolCallRounds}',
          'max': '${SettingsRepository.maxMaxToolCallRounds}',
        }),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await logic.setMaxToolCallRounds(result);
  }

  Future<void> _showModelDialog(
    BuildContext context, {
    ModelConfig? model,
  }) async {
    final tagController = TextEditingController(text: model?.tag ?? '');
    final apiUrlController = TextEditingController(text: model?.apiUrl ?? '');
    final apiKeyController = TextEditingController(text: model?.apiKey ?? '');
    final defaultModelController = TextEditingController(
      text: model?.defaultModel ?? '',
    );
    final modelsController = TextEditingController(
      text: model?.models.join(', ') ?? '',
    );
    final contextLimitController = TextEditingController(
      text: model?.contextLimit?.toString() ?? '',
    );

    var apiType = model?.apiType ?? ModelConfig.apiTypeOpenAi;
    var isDefault = model?.isDefault ?? logic.state.models.isEmpty;
    var temperature = model?.temperature ?? 0.7;
    var fetchedModels = [...model?.models ?? const <String>[]];
    var isFetchingModels = false;
    var isResolvingContext = false;
    var detectedContextLimit = model?.detectedContextLimit;
    var contextLimitManuallySet = model?.contextLimitManuallySet ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              model == null
                  ? 'settings.dialog.add_model'.tr
                  : 'settings.dialog.edit_model'.tr,
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tagController,
                      decoration: InputDecoration(
                        labelText: 'settings.field.tag'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: apiType,
                      decoration: InputDecoration(
                        labelText: 'settings.field.api_type'.tr,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ModelConfig.apiTypeOpenAi,
                          child: Text('OpenAI'),
                        ),
                        DropdownMenuItem(
                          value: ModelConfig.apiTypeAnthropic,
                          child: Text('Anthropic'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => apiType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiUrlController,
                      decoration: InputDecoration(
                        labelText: 'settings.field.api_url'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'settings.field.api_key'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isFetchingModels
                            ? null
                            : () async {
                                final apiUrl = apiUrlController.text.trim();
                                final apiKey = apiKeyController.text.trim();
                                if (apiUrl.isEmpty || apiKey.isEmpty) {
                                  Get.snackbar(
                                    'settings.snackbar.request_unavailable'.tr,
                                    'settings.snackbar.fill_url_key'.tr,
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return;
                                }

                                setState(() => isFetchingModels = true);
                                try {
                                  final models = await logic.fetchModels(
                                    apiType: apiType,
                                    apiUrl: apiUrl,
                                    apiKey: apiKey,
                                  );
                                  fetchedModels = models;
                                  modelsController.text = models.join(', ');

                                  final currentDefault =
                                      defaultModelController.text.trim();
                                  if (models.isNotEmpty &&
                                      (currentDefault.isEmpty ||
                                          !models.contains(currentDefault))) {
                                    defaultModelController.text = models.first;
                                  }

                                  if (models.isEmpty) {
                                    Get.snackbar(
                                      'settings.snackbar.request_done'.tr,
                                      'settings.snackbar.empty_model_list'.tr,
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  } else {
                                    Get.snackbar(
                                      'settings.snackbar.request_success'.tr,
                                      'settings.snackbar.models_fetched'.trParams(
                                        {'count': '${models.length}'},
                                      ),
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                } catch (e) {
                                  Get.snackbar(
                                    'settings.snackbar.request_failed'.tr,
                                    e.toString(),
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setState(() => isFetchingModels = false);
                                  }
                                }
                              },
                        icon: isFetchingModels
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                        label: Text(
                          isFetchingModels
                              ? 'settings.fetching_models'.tr
                              : 'settings.fetch_models'.tr,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: defaultModelController,
                      decoration: InputDecoration(
                        labelText: 'settings.field.default_model'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modelsController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'settings.field.models'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contextLimitController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        contextLimitManuallySet = true;
                      },
                      decoration: InputDecoration(
                        labelText: 'settings.field.context_limit'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isResolvingContext
                            ? null
                            : () async {
                                final apiUrl = apiUrlController.text.trim();
                                final apiKey = apiKeyController.text.trim();
                                final modelName =
                                    defaultModelController.text.trim();
                                if (modelName.isEmpty) {
                                  Get.snackbar(
                                    'settings.snackbar.detect_unavailable'.tr,
                                    'settings.snackbar.fill_default_model'.tr,
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return;
                                }

                                setState(() => isResolvingContext = true);
                                try {
                                  final limit = await logic.resolveContextLimit(
                                    apiType: apiType,
                                    apiUrl: apiUrl,
                                    apiKey: apiKey,
                                    modelName: modelName,
                                  );
                                  detectedContextLimit = limit;
                                  contextLimitController.text =
                                      limit.toString();
                                  contextLimitManuallySet = false;
                                  Get.snackbar(
                                    'settings.snackbar.detect_done'.tr,
                                    'settings.snackbar.context_limit_updated'
                                        .trParams({'value': '$limit'}),
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                } catch (e) {
                                  Get.snackbar(
                                    'settings.snackbar.detect_failed'.tr,
                                    e.toString(),
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setState(() => isResolvingContext = false);
                                  }
                                }
                              },
                        icon: isResolvingContext
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high_outlined),
                        label: Text(
                          isResolvingContext
                              ? 'settings.resolving_context_limit'.tr
                              : 'settings.resolve_context_limit'.tr,
                        ),
                      ),
                    ),
                    if (detectedContextLimit != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'settings.last_detected_context_limit'.trParams({
                            'value': '$detectedContextLimit',
                          }),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'settings.model.temperature'.trParams({
                              'value': temperature.toStringAsFixed(2),
                            }),
                          ),
                        ),
                        Switch(
                          value: isDefault,
                          onChanged: (value) {
                            setState(() => isDefault = value);
                          },
                        ),
                        Text('settings.set_as_default'.tr),
                      ],
                    ),
                    Slider(
                      value: temperature,
                      min: 0,
                      max: 2,
                      divisions: 20,
                      label: temperature.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() => temperature = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr),
              ),
              FilledButton(
                onPressed: () async {
                  final tag = tagController.text.trim();
                  if (tag.isEmpty) {
                    Get.snackbar(
                      'settings.snackbar.save_failed'.tr,
                      'settings.snackbar.empty_tag'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                    return;
                  }

                  var parsedModels = modelsController.text
                      .split(RegExp(r'[\n,]'))
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toSet()
                      .toList();
                  final defaultModel = defaultModelController.text.trim();
                  if (defaultModel.isNotEmpty &&
                      !parsedModels.contains(defaultModel)) {
                    parsedModels.insert(0, defaultModel);
                  }
                  if (fetchedModels.isNotEmpty && parsedModels.isEmpty) {
                    parsedModels = [...fetchedModels];
                  }

                  final config = ModelConfig(
                    id: model?.id ?? const Uuid().v4(),
                    tag: tag,
                    apiType: apiType,
                    apiUrl: apiUrlController.text.trim(),
                    apiKey: apiKeyController.text.trim(),
                    models: parsedModels,
                    defaultModel: defaultModel.isEmpty ? null : defaultModel,
                    contextLimit: int.tryParse(
                      contextLimitController.text.trim(),
                    ),
                    detectedContextLimit: detectedContextLimit,
                    contextLimitManuallySet: contextLimitManuallySet,
                    temperature: temperature,
                    isDefault: isDefault,
                    createdAt:
                        model?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
                  );

                  if (model == null) {
                    await logic.addModel(config);
                  } else {
                    await logic.updateModel(config);
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: Text('common.confirm'.tr),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      return;
    }
  }

  String _themeLabel(String value) {
    switch (value) {
      case 'light':
        return 'settings.theme.light'.tr;
      case 'dark':
        return 'settings.theme.dark'.tr;
      default:
        return 'settings.theme.system'.tr;
    }
  }

  String _languageLabel(String value) {
    switch (value) {
      case 'zh':
        return 'settings.language.zh'.tr;
      case 'en':
        return 'settings.language.en'.tr;
      default:
        return 'settings.language.system'.tr;
    }
  }
}
