import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl}) : _client = http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    return _client.get(Uri.parse('$baseUrl$path'), headers: headers);
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool asForm = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    if (asForm) {
      final formData = <String, String>{};
      for (final entry in (body ?? {}).entries) {
        formData[entry.key] = entry.value.toString();
      }
      return _client.post(uri, headers: headers, body: formData);
    }

    return _client.post(
      uri,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body ?? {}),
    );
  }

  void dispose() => _client.close();
}
