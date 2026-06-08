import 'package:shared_preferences/shared_preferences.dart';

import '../data/model/model_config.dart';

class ModelConfigManager {
  static const _keyModels = 'model_configs';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyModels)) {
      await prefs.setString(_keyModels, ModelConfig.listToJson(const []));
    }
  }

  Future<List<ModelConfig>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyModels);
    if (json == null || json.isEmpty) {
      return [];
    }
    try {
      return ModelConfig.listFromJson(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> add(ModelConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final models = await getAll();
    final nextModels = [...models, config];
    await _save(nextModels, prefs);
  }

  Future<void> update(ModelConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final models = await getAll();
    final index = models.indexWhere((item) => item.id == config.id);
    if (index == -1) {
      return;
    }
    models[index] = config;
    await _save(models, prefs);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final models = await getAll();
    models.removeWhere((item) => item.id == id);
    if (models.isNotEmpty && !models.any((item) => item.isDefault)) {
      models[0] = models[0].copyWith(isDefault: true);
    }
    await _save(models, prefs);
  }

  Future<void> _save(
    List<ModelConfig> models,
    SharedPreferences prefs,
  ) async {
    final normalized = _normalizeDefaults(models);
    await prefs.setString(_keyModels, ModelConfig.listToJson(normalized));
  }

  List<ModelConfig> _normalizeDefaults(List<ModelConfig> models) {
    if (models.isEmpty) {
      return models;
    }

    final defaultIndex = models.indexWhere((item) => item.isDefault);
    if (defaultIndex == -1) {
      return [
        models.first.copyWith(isDefault: true),
        ...models.skip(1).map((item) => item.copyWith(isDefault: false)),
      ];
    }

    return List<ModelConfig>.generate(models.length, (index) {
      final model = models[index];
      return model.copyWith(isDefault: index == defaultIndex);
    });
  }
}
