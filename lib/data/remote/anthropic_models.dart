class AnthropicModelsResponse {
  final List<AnthropicModelInfo> data;

  const AnthropicModelsResponse({
    required this.data,
  });

  factory AnthropicModelsResponse.fromJson(Map<String, dynamic> json) {
    return AnthropicModelsResponse(
      data: (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AnthropicModelInfo.fromJson)
          .toList(),
    );
  }
}

class AnthropicModelInfo {
  final String id;
  final int? maxInputTokens;

  const AnthropicModelInfo({
    required this.id,
    required this.maxInputTokens,
  });

  factory AnthropicModelInfo.fromJson(Map<String, dynamic> json) {
    return AnthropicModelInfo(
      id: json['id']?.toString() ?? '',
      maxInputTokens: _readInt(
        json['max_input_tokens'] ?? json['maxInputTokens'],
      ),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
