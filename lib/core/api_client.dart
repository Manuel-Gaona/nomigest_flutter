import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

/// Error devuelto por la API (o de conexión, con [status] 0).
class ApiException implements Exception {
  final String message;
  final int status;

  /// Errores por campo: {"nombre": "Campo obligatorio."}
  final Map<String, String> errores;

  const ApiException(this.message, this.status, [this.errores = const {}]);

  @override
  String toString() => message;
}

/// Cliente HTTP único de la app. Agrega el token y convierte las respuestas.
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  static const _timeout = Duration(seconds: 25);
  http.Client _http = http.Client();

  /// Permite sustituir el cliente HTTP en pruebas.
  set cliente(http.Client cliente) => _http = cliente;

  String baseUrl = AppConfig.defaultBaseUrl;
  String? token;

  /// Se llama cuando el servidor rechaza el token (sesión expirada o revocada).
  void Function()? onUnauthorized;

  Uri _uri(String path, Map<String, dynamic>? query) {
    final params = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    final uri = Uri.parse('$baseUrl/api$path');
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _http.post(_uri(path, null), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _http.put(_uri(path, null), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) => _send(() => _http.delete(_uri(path, null), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('El servidor no responde. Verifica tu conexión.', 0);
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor ($baseUrl).', 0);
    }

    dynamic body;
    if (response.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        body = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final mensaje = body is Map && body['error'] != null
        ? '${body['error']}'
        : 'Error del servidor (${response.statusCode}).';
    final errores = <String, String>{
      if (body is Map && body['errores'] is Map)
        for (final e in (body['errores'] as Map).entries) '${e.key}': '${e.value}',
    };
    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException(mensaje, response.statusCode, errores);
  }
}

final api = ApiClient.instance;
