import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/server_config.dart';
import '../core/constants/api_constants.dart';

/// Exceção padronizada para erros de API.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  /// true quando o servidor nem respondeu (sem rede, IP errado, API desligada).
  bool get semConexao => statusCode == null;

  @override
  String toString() => message;
}

/// Encapsula chamadas HTTP ao backend NestJS.
class ApiClient {
  static const _tokenKey = 'indusense_token';
  static String? _tokenCache;

  static Future<String?> getToken() async {
    if (_tokenCache != null) return _tokenCache;
    final prefs = await SharedPreferences.getInstance();
    _tokenCache = prefs.getString(_tokenKey);
    return _tokenCache;
  }

  static Future<void> saveToken(String token) async {
    _tokenCache = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    _tokenCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Cabeçalho de autenticação para imagens protegidas (fotos das ocorrências).
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'};
  }

  /// "/v1/epi/ocorrencias/123/foto" -> "http://IP:3333/v1/epi/ocorrencias/123/foto"
  static String absoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ServerConfig.apiOrigin}${path.startsWith('/') ? path : '/$path'}';
  }

  /// Identifica o app nas sessões ("App InduSense · iPhone" no painel e no app).
  static String get userAgent {
    if (kIsWeb) return 'InduSenseApp/1.0 (Dart; Web)';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'InduSenseApp/1.0 (Dart; iPhone; iOS)';
      case TargetPlatform.android:
        return 'InduSenseApp/1.0 (Dart; Android; Mobile)';
      case TargetPlatform.macOS:
        return 'InduSenseApp/1.0 (Dart; Macintosh; Mac OS X)';
      case TargetPlatform.windows:
        return 'InduSenseApp/1.0 (Dart; Windows)';
      default:
        return 'InduSenseApp/1.0 (Dart; Linux)';
    }
  }

  Future<Map<String, String>> _headers() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (!kIsWeb) 'User-Agent': userAgent,
      ...await authHeaders(),
    };
  }

  Uri _buildUri(String path) {
    final base = ApiConstants.baseUrl.endsWith('/')
        ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1)
        : ApiConstants.baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath');
  }

  Future<dynamic> get(String path) =>
      _send('GET', path, (uri, h) => http.get(uri, headers: h));

  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, (uri, h) => http.post(uri, headers: h, body: jsonEncode(body)));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _send('PATCH', path, (uri, h) => http.patch(uri, headers: h, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) =>
      _send('DELETE', path, (uri, h) => http.delete(uri, headers: h));

  Future<dynamic> _send(
    String method,
    String path,
    Future<http.Response> Function(Uri uri, Map<String, String> headers) call,
  ) async {
    final uri = _buildUri(path);
    try {
      final res = await call(uri, await _headers()).timeout(ApiConstants.timeout);
      return _handle(res);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('O servidor demorou demais para responder (${ServerConfig.apiOrigin}).');
    } catch (e) {
      if (kDebugMode) debugPrint('[api] $method $uri falhou: $e');
      throw ApiException(
        'Sem conexão com o servidor em ${ServerConfig.apiOrigin}. '
        'Confira se a API está ligada e o endereço em Perfil > Servidor.',
      );
    }
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        throw ApiException('O servidor respondeu, mas a resposta não é um JSON válido.',
            statusCode: res.statusCode);
      }
    }

    String message = 'Erro ao comunicar com o servidor.';
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final rawMessage = decoded is Map ? decoded['message'] : null;
      if (rawMessage is List && rawMessage.isNotEmpty) {
        message = rawMessage.first.toString();
      } else if (rawMessage != null) {
        message = rawMessage.toString();
      }
    } catch (_) {}

    if (kDebugMode) debugPrint('[api] HTTP ${res.statusCode} ${res.request?.url}: $message');

    if (res.statusCode == 401) message = 'Sessão expirada. Faça login novamente.';
    if (res.statusCode == 403) message = 'Seu perfil não tem permissão para esta ação.';

    throw ApiException(message, statusCode: res.statusCode);
  }
}
