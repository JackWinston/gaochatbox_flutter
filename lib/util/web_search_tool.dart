import 'dart:math' as math;

import 'package:dio/dio.dart';

class WebSearchTool {
  Future<String> searchQuery(String query) async {
    try {
      final ddg = await _searchDuckDuckGo(query);
      if (ddg.isNotEmpty) {
        return _formatSearchResults(query, ddg);
      }
    } catch (_) {}
    try {
      final bing = await _searchBing(query);
      if (bing.isNotEmpty) {
        return _formatSearchResults(query, bing);
      }
      return '未找到与"$query"相关的搜索结果';
    } catch (_) {
      return '搜索失败: 网络超时或搜索服务暂时不可用，请稍后重试';
    }
  }

  Future<String> fetchContent(String inputUrl) async {
    try {
      final url = _normalizeUrl(inputUrl);
      final response = await _newClient().get<String>(
        url,
        options: Options(headers: _browserHeaders(url)),
      );
      final body = response.data?.trim() ?? '';
      final title = _extractTitle(body);
      final content = _extractReadableContent(body);
      return [
        '以下是 $url 的网页内容：',
        if (title.isNotEmpty) '标题: $title',
        '',
        content,
      ].join('\n').trim();
    } catch (e) {
      return '网页内容获取失败: $e';
    }
  }

  Future<List<_SearchResult>> _searchDuckDuckGo(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = 'https://html.duckduckgo.com/html/?q=$encodedQuery';
    final response = await _newClient().get<String>(
      url,
      options: Options(headers: _browserHeaders(url)),
    );
    return _parseDuckDuckGoHtml(response.data ?? '');
  }

  Future<List<_SearchResult>> _searchBing(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = 'https://www.bing.com/search?q=$encodedQuery&setlang=zh-Hans';
    final response = await _newClient().get<String>(
      url,
      options: Options(headers: _browserHeaders(url)),
    );
    return _parseBingHtml(response.data ?? '');
  }

  Dio _newClient() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
        followRedirects: true,
      ),
    );
  }

  String _formatSearchResults(String query, List<_SearchResult> results) {
    if (results.isEmpty) {
      return '未找到与"$query"相关的搜索结果';
    }
    final buffer = StringBuffer('以下是"$query"的搜索结果：\n\n');
    for (var index = 0; index < results.length; index++) {
      final item = results[index];
      buffer
        ..writeln('${index + 1}. ${item.title}')
        ..writeln('   链接: ${item.url}')
        ..writeln('   摘要: ${item.snippet}')
        ..writeln();
    }
    return buffer.toString().trim();
  }

  List<_SearchResult> _parseDuckDuckGoHtml(String html) {
    final anchorRegex = RegExp(
      '<a[^>]+class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final snippetRegex = RegExp(
      '<a[^>]+class="result__snippet"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final anchors = anchorRegex.allMatches(html).toList();
    final snippets = snippetRegex.allMatches(html).toList();
    final results = <_SearchResult>[];
    for (
      var index = 0;
      index < anchors.length && results.length < 10;
      index++
    ) {
      final match = anchors[index];
      final rawUrl = match.group(1) ?? '';
      final rawTitle = match.group(2) ?? '';
      final snippet = index < snippets.length
          ? _stripHtml(snippets[index].group(1) ?? '')
          : '';
      final title = _stripHtml(rawTitle);
      final url = _extractRedirectUrl(rawUrl);
      if (title.isNotEmpty && url.isNotEmpty) {
        results.add(_SearchResult(title: title, url: url, snippet: snippet));
      }
    }
    return results;
  }

  List<_SearchResult> _parseBingHtml(String html) {
    final blockRegex = RegExp(
      '<li[^>]+class="[^"]*\\bb_algo\\b[^"]*"[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    final insideAnchorRegex = RegExp(
      '<a[^>]*href="([^"]+)"[^>]*>\\s*<h2[^>]*>(.*?)</h2>\\s*</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final outsideAnchorRegex = RegExp(
      '<h2[^>]*>\\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>\\s*</h2>',
      caseSensitive: false,
      dotAll: true,
    );
    final snippetRegex = RegExp(
      '<p[^>]*>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    );
    final results = <_SearchResult>[];
    for (final blockMatch in blockRegex.allMatches(html)) {
      if (results.length >= 10) {
        break;
      }
      final block = blockMatch.group(1) ?? '';
      final titleMatch =
          insideAnchorRegex.firstMatch(block) ??
          outsideAnchorRegex.firstMatch(block);
      if (titleMatch == null) {
        continue;
      }
      final url = _stripHtml(titleMatch.group(1) ?? '');
      final title = _stripHtml(titleMatch.group(2) ?? '');
      final snippet = _stripHtml(
        snippetRegex.firstMatch(block)?.group(1) ?? '',
      );
      if (title.isNotEmpty && url.isNotEmpty) {
        results.add(_SearchResult(title: title, url: url, snippet: snippet));
      }
    }
    return results;
  }

  String _extractRedirectUrl(String rawUrl) {
    final uddg = RegExp('uddg=([^&]+)').firstMatch(rawUrl)?.group(1);
    return uddg == null ? rawUrl : Uri.decodeComponent(uddg);
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String _extractTitle(String html) {
    final match = RegExp(
      '<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return _stripHtml(match?.group(1) ?? '');
  }

  String _extractReadableContent(String body) {
    final normalized = body.trim();
    if (normalized.isEmpty) {
      return '网页内容为空';
    }
    if (!normalized.toLowerCase().contains('<html') &&
        !normalized.toLowerCase().contains('<body')) {
      return normalized.substring(0, math.min(normalized.length, 6000));
    }
    final withoutScripts = normalized
        .replaceAll(
          RegExp(
            '<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp('<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
          ' ',
        )
        .replaceAll(
          RegExp(
            '<noscript[^>]*>.*?</noscript>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        );
    final text = _stripHtml(
      withoutScripts,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      return '未提取到可读正文';
    }
    return text.substring(0, math.min(text.length, 6000));
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp('<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  Map<String, String> _browserHeaders(String url) {
    final uri = Uri.tryParse(url);
    final referer = uri == null
        ? 'https://www.google.com/'
        : '${uri.scheme}://${uri.host}/';
    return {
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'referer': referer,
    };
  }
}

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;
}
