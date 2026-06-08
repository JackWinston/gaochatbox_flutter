import 'package:dio/dio.dart';

class ApiClient {
  static Dio buildOpenAiClient(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: normalizeOpenAiUrl(baseUrl),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );
  }

  static Dio buildAnthropicClient(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: normalizeAnthropicUrl(baseUrl),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );
  }

  static String normalizeOpenAiUrl(String url) {
    var normalized = url.trim().trimRight();
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    const suffixes = [
      '/chat/completions',
      '/completions',
      '/embeddings',
      '/models',
    ];
    for (final suffix in suffixes) {
      if (normalized.toLowerCase().endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    if (!normalized.endsWith('/v1')) {
      normalized = '$normalized/v1';
    }
    return '$normalized/';
  }

  static String normalizeAnthropicUrl(String url) {
    var normalized = url.trim().trimRight();
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    const suffixes = ['/messages', '/complete', '/models'];
    for (final suffix in suffixes) {
      if (normalized.toLowerCase().endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    if (!normalized.endsWith('/v1')) {
      normalized = '$normalized/v1';
    }
    return '$normalized/';
  }
}
