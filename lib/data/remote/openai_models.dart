class OpenAiModelsResponse {
  final List<OpenAiModelInfo> data;

  const OpenAiModelsResponse({
    required this.data,
  });

  factory OpenAiModelsResponse.fromJson(Map<String, dynamic> json) {
    return OpenAiModelsResponse(
      data: (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpenAiModelInfo.fromJson)
          .toList(),
    );
  }
}

class OpenAiModelInfo {
  final String id;
  final int? contextLength;

  const OpenAiModelInfo({
    required this.id,
    required this.contextLength,
  });

  factory OpenAiModelInfo.fromJson(Map<String, dynamic> json) {
    return OpenAiModelInfo(
      id: json['id']?.toString() ?? '',
      contextLength: _readInt(
        json['context_length'] ??
            json['contextLength'] ??
            json['max_context_length'] ??
            json['maxContextLength'] ??
            json['input_token_limit'],
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
