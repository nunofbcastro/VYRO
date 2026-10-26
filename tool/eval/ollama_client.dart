/// Minimal client for a local Ollama server (`/api/generate`, `/api/version`).
/// Used only by the offline evaluation harness; the app itself never calls it.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class OllamaClient {
  OllamaClient({
    required this.baseUrl,
    required this.model,
    required this.numCtx,
    this.timeout = const Duration(minutes: 5),
  });

  final Uri baseUrl;
  final String model;
  final int numCtx;
  final Duration timeout;

  /// Server version string, e.g. `0.9.6`. Throws when the server is down.
  Future<String> version() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(baseUrl.resolve('/api/version'))
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('version ${response.statusCode}: $body');
      }
      return (jsonDecode(body) as Map<String, dynamic>)['version'] as String;
    } finally {
      client.close(force: true);
    }
  }

  /// One completion with optional images (JPEG bytes). Returns the answer text.
  Future<String> generate({
    required String prompt,
    required List<Uint8List> images,
    required double temperature,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final body = jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
        if (images.isNotEmpty)
          'images': [for (final image in images) base64Encode(image)],
        'options': {'temperature': temperature, 'num_ctx': numCtx},
      });
      final request = await client
          .postUrl(baseUrl.resolve('/api/generate'))
          .timeout(const Duration(seconds: 10));
      final bytes = utf8.encode(body);
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close().timeout(timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw HttpException('ollama ${response.statusCode}: $text');
      }
      final json = jsonDecode(text) as Map<String, dynamic>;
      return (json['response'] as String?) ?? '';
    } finally {
      client.close(force: true);
    }
  }
}
