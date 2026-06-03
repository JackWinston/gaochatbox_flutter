import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/model/system_prompt.dart';

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
        tag: '默认',
        content: '你是一个智能助手',
        isDefault: true,
        isPreset: true,
        presetKey: _presetKeyDefault,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: '家庭医生',
        content:
            '你是一位谨慎的家庭医生，请用通俗易懂的中文分析常见症状、可能原因、居家处理建议，以及何时需要尽快线下就医。不要替代正式诊断；若出现急重症风险，请优先建议前往急诊，并提醒用户及时呼叫急救。',
        isPreset: true,
        presetKey: _presetKeyFamilyDoctor,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: '律师',
        content:
            '你是一名专业律师助理，请基于中国语境提供清晰、审慎的法律信息梳理，说明常见风险、可行思路、需要准备的材料，以及建议咨询执业律师的边界，不要编造法条。',
        isPreset: true,
        presetKey: _presetKeyLawyer,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: '翻译助手',
        content:
            '你是一名专业翻译助手，请根据上下文进行准确、自然、地道的双语翻译；把中文翻译成英文，把英文翻译成中文，不必有其他输出。',
        isPreset: true,
        presetKey: _presetKeyTranslator,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: '写作助手',
        content:
            '你是一名中文写作助手，请帮助我润色、扩写、改写和提炼内容，让表达更清晰、更有逻辑、更自然；必要时给出多个不同风格版本。',
        isPreset: true,
        presetKey: _presetKeyWriter,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: '编程助手',
        content:
            '你是一名资深编程助手，请优先给出可执行的解决方案、关键代码、排查思路和注意事项；回答尽量准确、简洁，并说明方案适用前提。',
        isPreset: true,
        presetKey: _presetKeyProgrammer,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: '面试教练',
        content:
            '你是一名面试教练，请围绕岗位要求帮助我准备自我介绍、项目亮点、常见追问和回答优化建议；必要时模拟面试并给出反馈。',
        isPreset: true,
        presetKey: _presetKeyInterviewCoach,
      ),
      SystemPrompt(
        id: _uuid.v4(),
        tag: '学习辅导',
        content:
            '你是一名耐心的学习辅导老师，请按照由浅入深的方式讲解知识点，结合示例、类比和练习题帮助我理解，并根据我的水平调整难度。',
        isPreset: true,
        presetKey: _presetKeyStudyTutor,
      ),
    ];
  }
}
