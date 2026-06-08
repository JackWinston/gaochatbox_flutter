import 'package:dio/dio.dart';

import 'api_client.dart';
import 'openai_models.dart';

class OpenAiApi {
  OpenAiApi(String baseUrl) : _dio = ApiClient.buildOpenAiClient(baseUrl);

  final Dio _dio;

  Future<OpenAiModelsResponse> getModels(String apiKey) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'models',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );
    return OpenAiModelsResponse.fromJson(response.data ?? const {});
  }
}
