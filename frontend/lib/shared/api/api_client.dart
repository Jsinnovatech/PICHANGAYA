import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

/// Equivale al fetch() con JWT del HTML + interceptors
class ApiClient {
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;
  ApiClient._();

  final _storage = const FlutterSecureStorage();
  Dio? _dio;

  // Lock para evitar race condition cuando varios requests intentan
  // refrescar el token al mismo tiempo (ej: FCM + reportes en startup)
  bool _refreshing = false;
  final List<Completer<bool>> _refreshQueue = [];

  Dio get dio {
    _dio ??= _build();
    return _dio!;
  }

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) opts.headers['Authorization'] = 'Bearer $token';
        handler.next(opts);
      },
      onError: (err, handler) async {
        final path = err.requestOptions.path;
        if (err.response?.statusCode == 401 &&
            !path.contains('/auth/login') &&
            !path.contains('/auth/refresh')) {
          final ok = await _refreshTokenSerialized();
          if (ok) {
            final token = await _storage.read(key: 'access_token');
            err.requestOptions.headers['Authorization'] = 'Bearer $token';
            final resp = await d.fetch(err.requestOptions);
            return handler.resolve(resp);
          }
        }
        handler.next(err);
      },
    ));

    return d;
  }

  /// Serializa los refreshes: solo uno corre a la vez.
  /// Los demás esperan el resultado del primero.
  Future<bool> _refreshTokenSerialized() async {
    if (_refreshing) {
      // Ya hay un refresh en curso — esperar su resultado
      final completer = Completer<bool>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _refreshing = true;
    final result = await _refreshToken();
    _refreshing = false;

    // Notificar a todos los que estaban esperando
    for (final c in _refreshQueue) {
      c.complete(result);
    }
    _refreshQueue.clear();

    return result;
  }

  Future<bool> _refreshToken() async {
    try {
      final rt = await _storage.read(key: 'refresh_token');
      if (rt == null) return false;
      final resp = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.refresh}',
        data: {'refresh_token': rt},
      );
      await saveTokens(
        access: resp.data['access_token'],
        refresh: resp.data['refresh_token'],
      );
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    _dio = null; // fuerza rebuild con nuevo token
  }

  Future<void> saveUser(String userJson) async =>
      _storage.write(key: 'user_json', value: userJson);

  Future<String?> getUserJson() => _storage.read(key: 'user_json');

  Future<void> logout() async {
    await _storage.deleteAll();
    _dio = null;
  }

  Future<bool> isLoggedIn() async =>
      (await _storage.read(key: 'access_token')) != null;

  Future<String?> getRol() => _storage.read(key: 'user_rol');
  Future<void> saveRol(String rol) => _storage.write(key: 'user_rol', value: rol);
}
