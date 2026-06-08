import '../data/model/model_config.dart';
import '../data/remote/anthropic_api.dart';
import '../data/remote/openai_api.dart';

class ModelContextLimitResolver {
  static const defaultContextLimit = 65536;

  final Map<String, int> _cache = {};

  Future<int> resolve({
    required String apiType,
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) async {
    final normalizedModel = modelName.trim();
    if (normalizedModel.isEmpty) {
      return defaultContextLimit;
    }

    final cacheKey = _buildCacheKey(apiType, apiUrl, normalizedModel);
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final resolved =
            await _discoverRemote(
              apiType: apiType,
              apiUrl: apiUrl,
              apiKey: apiKey,
              modelName: normalizedModel,
            ) ??
        resolveStatic(apiType: apiType, modelName: normalizedModel) ??
        defaultContextLimit;

    _cache[cacheKey] = resolved;
    return resolved;
  }

  Future<int?> _discoverRemote({
    required String apiType,
    required String apiUrl,
    required String apiKey,
    required String modelName,
  }) async {
    if (apiUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      return null;
    }

    try {
      if (apiType == ModelConfig.apiTypeAnthropic) {
        final api = AnthropicApi(apiUrl);
        final single = await api.getModel(apiKey, modelName);
        if ((single?.maxInputTokens ?? 0) > 0) {
          return single!.maxInputTokens;
        }
        final list = await api.getModels(apiKey);
        return list.data
            .where((item) => item.id == modelName)
            .map((item) => item.maxInputTokens)
            .whereType<int>()
            .cast<int?>()
            .firstWhere((item) => item != null, orElse: () => null);
      }

      final api = OpenAiApi(apiUrl);
      final list = await api.getModels(apiKey);
      return list.data
          .where((item) => item.id == modelName)
          .map((item) => item.contextLength)
          .whereType<int>()
          .cast<int?>()
          .firstWhere((item) => item != null, orElse: () => null);
    } catch (_) {
      return null;
    }
  }

  int? resolveStatic({
    required String apiType,
    required String modelName,
  }) {
    final normalized = modelName.trim().toLowerCase();
    if (apiType == ModelConfig.apiTypeAnthropic) {
      return _resolveAnthropicStatic(normalized);
    }
    return _resolveOpenAiStatic(normalized);
  }

  int? _resolveOpenAiStatic(String modelName) {
    if (modelName.startsWith('gpt-5.5')) return 1050000;
    if (modelName.startsWith('gpt-5.4')) {
      if (modelName.contains('mini') || modelName.contains('nano')) {
        return 400000;
      }
      return 1050000;
    }
    if (modelName.startsWith('gpt-5.3-codex')) return 400000;
    if (modelName.startsWith('gpt-5.2')) return 400000;
    if (modelName.startsWith('gpt-5.1')) return 400000;
    if (modelName == 'gpt-5' || modelName.startsWith('gpt-5-')) return 400000;
    if (modelName.startsWith('gpt-4.1')) return 1047576;
    if (modelName.startsWith('gpt-4o') || modelName.startsWith('chatgpt-4o')) {
      return 128000;
    }
    if (modelName == 'o1' || modelName.startsWith('o1-')) return 200000;
    if (modelName == 'o3' || modelName.startsWith('o3-')) return 200000;
    if (modelName == 'o4-mini' || modelName.startsWith('o4-mini')) {
      return 200000;
    }
    if (modelName.startsWith('gpt-oss-')) return 131072;
    if (modelName.startsWith('deepseek-v4')) return 1000000;
    if (modelName.startsWith('deepseek-v3') ||
        modelName.startsWith('deepseek-r1')) {
      return 128000;
    }
    if (modelName.startsWith('deepseek-v2') ||
        modelName.startsWith('deepseek-coder') ||
        modelName.startsWith('deepseek')) {
      return 128000;
    }
    if (modelName.startsWith('minimax-m3') ||
        modelName.startsWith('minimax-m2') ||
        modelName.startsWith('minimax-text') ||
        modelName.startsWith('minimax')) {
      return 1000000;
    }
    if (modelName.startsWith('mimo-v2.5') ||
        modelName.startsWith('mimo-v2-pro') ||
        modelName.startsWith('mimo-v2')) {
      return 1000000;
    }
    if (modelName.startsWith('mimo')) return 32768;
    return null;
  }

  int? _resolveAnthropicStatic(String modelName) {
    if (modelName.startsWith('claude-opus-4-8')) return 1000000;
    if (modelName.startsWith('claude-opus-4-7')) return 1000000;
    if (modelName.startsWith('claude-opus-4-6')) return 1000000;
    if (modelName.startsWith('claude-sonnet-4-6')) return 1000000;
    if (modelName.contains('haiku') ||
        modelName.contains('sonnet') ||
        modelName.contains('opus')) {
      return 200000;
    }
    return null;
  }

  String _buildCacheKey(String apiType, String apiUrl, String modelName) {
    final normalizedUrl = apiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '${apiType.toLowerCase()}|${normalizedUrl.toLowerCase()}|${modelName.toLowerCase()}';
  }
}
