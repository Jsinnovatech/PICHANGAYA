import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

/// Cliente HTTP singleton con JWT automático + refresh token
class ApiClient {
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;
  ApiClient._();

  final _storage = const FlutterSecureStorage();
  Dio? _dio;

  Dio get dio {
    _dio ??= _build();
    return _dio!;
  }

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) opts.headers['Authorization'] = 'Bearer $token';
        handler.next(opts);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401) {
          if (await _refreshToken()) {
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

  // Fuerza rebuild del Dio con la URL correcta para la plataforma actual
  void resetDio() => _dio = null;

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    _dio = null; // fuerza rebuild
  }

  Future<void> saveUser(String userJson) =>
      _storage.write(key: 'user_json', value: userJson);

  Future<String?> getUserJson() => _storage.read(key: 'user_json');

  Future<void> saveRol(String rol) =>
      _storage.write(key: 'user_rol', value: rol);

  Future<String?> getRol() => _storage.read(key: 'user_rol');

  Future<void> logout() async {
    await _storage.deleteAll();
    _dio = null;
  }

  Future<bool> isLoggedIn() async =>
      (await _storage.read(key: 'access_token')) != null;
}
