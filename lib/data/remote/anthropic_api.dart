import 'package:dio/dio.dart';

import 'anthropic_models.dart';
import 'api_client.dart';

class AnthropicApi {
  AnthropicApi(String baseUrl)
      : _dio = ApiClient.buildAnthropicClient(baseUrl);

  final Dio _dio;

  Future<AnthropicModelsResponse> getModels(String apiKey) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'models',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
      ),
    );
    return AnthropicModelsResponse.fromJson(response.data ?? const {});
  }

  Future<AnthropicModelInfo?> getModel(String apiKey, String modelId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'models/$modelId',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
      ),
    );
    final data = response.data;
    if (data == null) {
      return null;
    }
    return AnthropicModelInfo.fromJson(data);
  }
}
