import 'dart:convert';

class SystemPrompt {
  final String id;
  final String content;
  final String tag;
  final bool isDefault;
  final bool isPreset;
  final String? presetKey;
  final int createdAt;

  SystemPrompt({
    required this.id,
    required this.content,
    required this.tag,
    this.isDefault = false,
    this.isPreset = false,
    this.presetKey,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'tag': tag,
        'isDefault': isDefault,
        'isPreset': isPreset,
        'presetKey': presetKey,
        'createdAt': createdAt,
      };

  factory SystemPrompt.fromJson(Map<String, dynamic> json) => SystemPrompt(
        id: json['id'] as String,
        content: json['content'] as String,
        tag: json['tag'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
        isPreset: json['isPreset'] as bool? ?? false,
        presetKey: json['presetKey'] as String?,
        createdAt: json['createdAt'] as int?,
      );

  static List<SystemPrompt> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => SystemPrompt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<SystemPrompt> prompts) {
    return jsonEncode(prompts.map((e) => e.toJson()).toList());
  }
}
