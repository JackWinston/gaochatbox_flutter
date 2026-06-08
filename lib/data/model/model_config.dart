import 'dart:convert';

class ModelConfig {
  static const apiTypeOpenAi = 'openai';
  static const apiTypeAnthropic = 'anthropic';

  final String id;
  final String tag;
  final String apiType;
  final String apiUrl;
  final String apiKey;
  final List<String> models;
  final String? defaultModel;
  final int? contextLimit;
  final int? detectedContextLimit;
  final bool contextLimitManuallySet;
  final double temperature;
  final bool isDefault;
  final int createdAt;

  const ModelConfig({
    required this.id,
    required this.tag,
    required this.apiType,
    required this.apiUrl,
    required this.apiKey,
    this.models = const [],
    this.defaultModel,
    this.contextLimit,
    this.detectedContextLimit,
    this.contextLimitManuallySet = false,
    this.temperature = 0.7,
    this.isDefault = false,
    required this.createdAt,
  });

  ModelConfig copyWith({
    String? id,
    String? tag,
    String? apiType,
    String? apiUrl,
    String? apiKey,
    List<String>? models,
    String? defaultModel,
    int? contextLimit,
    int? detectedContextLimit,
    bool? contextLimitManuallySet,
    double? temperature,
    bool? isDefault,
    int? createdAt,
  }) {
    return ModelConfig(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      apiType: apiType ?? this.apiType,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      models: models ?? this.models,
      defaultModel: defaultModel ?? this.defaultModel,
      contextLimit: contextLimit ?? this.contextLimit,
      detectedContextLimit: detectedContextLimit ?? this.detectedContextLimit,
      contextLimitManuallySet:
          contextLimitManuallySet ?? this.contextLimitManuallySet,
      temperature: temperature ?? this.temperature,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'apiType': apiType,
        'apiUrl': apiUrl,
        'apiKey': apiKey,
        'models': models,
        'defaultModel': defaultModel,
        'contextLimit': contextLimit,
        'detectedContextLimit': detectedContextLimit,
        'contextLimitManuallySet': contextLimitManuallySet,
        'temperature': temperature,
        'isDefault': isDefault,
        'createdAt': createdAt,
      };

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      id: json['id'] as String,
      tag: json['tag'] as String? ?? '',
      apiType: json['apiType'] as String? ?? apiTypeOpenAi,
      apiUrl: json['apiUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      models: (json['models'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      defaultModel: json['defaultModel'] as String?,
      contextLimit: json['contextLimit'] as int?,
      detectedContextLimit: json['detectedContextLimit'] as int?,
      contextLimitManuallySet:
          json['contextLimitManuallySet'] as bool? ?? false,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  static List<ModelConfig> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((item) => ModelConfig.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<ModelConfig> models) {
    return jsonEncode(models.map((item) => item.toJson()).toList());
  }
}
