import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/model/system_prompt.dart';
import '../i18n/app_translations.dart';

class SystemPromptManager {
  static const _keyPrompts = 'system_prompts';
  static const _keyInitialized = 'initialized';
  static const _keyHiddenPresetKeys = 'hidden_system_prompt_preset_keys';

  static const _presetKeyDefault = 'default';
  static const _presetKeyFamilyDoctor = 'family_doctor';
  static const _presetKeyLawyer = 'lawyer';
  static const _presetKeyTranslator = 'translator';
  static const _presetKeyWriter = 'writer';
  static const _presetKeyProgrammer = 'programmer';
  static const _presetKeyInterviewCoach = 'interview_coach';
  static const _presetKeyStudyTutor = 'study_tutor';

  static const _uuid = Uuid();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(_keyInitialized) ?? false;
    final currentPrompts = await getAll();
    if (!initialized || currentPrompts.isEmpty) {
      await _initDefault(prefs);
    } else {
      await _syncDefaultPrompts(currentPrompts, prefs);
    }
  }

  Future<void> _initDefault(SharedPreferences prefs) async {
    final defaultPrompts = _buildDefaultPrompts();
    await prefs.setString(_keyPrompts, SystemPrompt.listToJson(defaultPrompts));
    await prefs.setBool(_keyInitialized, true);
  }

  Future<void> _syncDefaultPrompts(
    List<SystemPrompt> currentPrompts,
    SharedPreferences prefs,
  ) async {
    final hiddenPresetKeys = await _getHiddenPresetKeys();
    final builtPrompts = _buildDefaultPrompts();
    final defaultPrompt =
        builtPrompts.where((p) => p.isDefault).firstOrNull;
    final activePresetMap = {
      for (final p in builtPrompts
          .where((p) => !p.isDefault)
          .where((p) => !hiddenPresetKeys.contains(p.presetKey)))
        p.presetKey!: p,
    };

    final syncedPrompts = <SystemPrompt>[];
    if (defaultPrompt != null) syncedPrompts.add(defaultPrompt);

    final addedPresetKeys = <String>{};
    for (final prompt in currentPrompts.where((p) => !p.isDefault)) {
      if (prompt.isPreset) {
        final presetKey = prompt.presetKey;
        if (presetKey == null) continue;
        final rebuiltPrompt = activePresetMap[presetKey];
        if (rebuiltPrompt == null) continue;
        if (addedPresetKeys.add(presetKey)) {
          syncedPrompts.add(rebuiltPrompt);
        }
      } else {
        syncedPrompts.add(prompt);
      }
    }

    for (final prompt in activePresetMap.values) {
      final presetKey = prompt.presetKey;
      if (presetKey == null) continue;
      if (addedPresetKeys.add(presetKey)) {
        syncedPrompts.add(prompt);
      }
    }

    await _saveList(syncedPrompts, prefs);
  }

  Future<List<SystemPrompt>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyPrompts);
    if (json == null || json.isEmpty) return [];
    try {
      return SystemPrompt.listFromJson(json);
    } catch (_) {
      return [];
    }
  }

  Future<SystemPrompt?> getById(String id) async {
    final list = await getAll();
    return list.where((p) => p.id == id).firstOrNull;
  }

  Future<void> add(SystemPrompt prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    list.add(prompt);
    await _saveList(list, prefs);
  }

  Future<void> update(SystemPrompt prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final index = list.indexWhere((p) => p.id == prompt.id);
    if (index != -1) {
      list[index] = prompt;
      await _saveList(list, prefs);
    }
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final prompt = list.where((p) => p.id == id).firstOrNull;
    if (prompt == null) return;
    if (prompt.isDefault) return;
    if (prompt.isPreset) {
      await _addHiddenPresetKey(prompt.presetKey, prefs);
    }
    list.removeWhere((p) => p.id == id);
    await _saveList(list, prefs);
  }

  Future<void> reorderPrompts(List<SystemPrompt> orderedPrompts) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPrompts = await getAll();
    final defaultPrompt =
        currentPrompts.where((p) => p.isDefault).firstOrNull;
    final movablePromptMap = {
      for (final p in currentPrompts.where((p) => !p.isDefault)) p.id: p,
    };
    final reorderedPrompts = orderedPrompts
        .where((p) => !p.isDefault)
        .map((p) => movablePromptMap[p.id])
        .whereType<SystemPrompt>()
        .toList();
    if (reorderedPrompts.length != movablePromptMap.length) return;
    final result = [
      ?defaultPrompt,
      ...reorderedPrompts,
    ];
    await _saveList(result, prefs);
  }

  Future<void> _saveList(
    List<SystemPrompt> list,
    SharedPreferences prefs,
  ) async {
    await prefs.setString(_keyPrompts, SystemPrompt.listToJson(list));
  }

  Future<Set<String>> _getHiddenPresetKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyHiddenPresetKeys)?.toSet() ?? {};
  }

  Future<void> _addHiddenPresetKey(
    String? presetKey,
    SharedPreferences prefs,
  ) async {
    if (presetKey == null || presetKey.isEmpty) return;
    final keys = prefs.getStringList(_keyHiddenPresetKeys)?.toSet() ?? {};
    keys.add(presetKey);
    await prefs.setStringList(_keyHiddenPresetKeys, keys.toList());
  }

  List<SystemPrompt> _buildDefaultPrompts() {
    return [
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyDefault),
        content: AppTranslations.presetContent(_presetKeyDefault),
        isDefault: true,
        isPreset: true,
        presetKey: _presetKeyDefault,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyFamilyDoctor),
        content: AppTranslations.presetContent(_presetKeyFamilyDoctor),
        isPreset: true,
        presetKey: _presetKeyFamilyDoctor,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyLawyer),
        content: AppTranslations.presetContent(_presetKeyLawyer),
        isPreset: true,
        presetKey: _presetKeyLawyer,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyTranslator),
        content: AppTranslations.presetContent(_presetKeyTranslator),
        isPreset: true,
        presetKey: _presetKeyTranslator,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyWriter),
        content: AppTranslations.presetContent(_presetKeyWriter),
        isPreset: true,
        presetKey: _presetKeyWriter,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyProgrammer),
        content: AppTranslations.presetContent(_presetKeyProgrammer),
        isPreset: true,
        presetKey: _presetKeyProgrammer,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyInterviewCoach),
        content: AppTranslations.presetContent(_presetKeyInterviewCoach),
        isPreset: true,
        presetKey: _presetKeyInterviewCoach,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: AppTranslations.presetTag(_presetKeyStudyTutor),
        content: AppTranslations.presetContent(_presetKeyStudyTutor),
        isPreset: true,
        presetKey: _presetKeyStudyTutor,
      ),
    ];
  }
}
