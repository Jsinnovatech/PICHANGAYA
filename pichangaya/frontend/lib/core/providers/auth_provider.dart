import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/shared/models/user_model.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

// ── Estado ────────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final String? rol;
  final bool loading;
  final String? error;

  const AuthState({
    this.user,
    this.rol,
    this.loading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    String? rol,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user: clearUser ? null : user ?? this.user,
        rol: clearUser ? null : rol ?? this.rol,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Llámalo en SplashScreen para restaurar sesión desde storage.
  Future<void> init() async {
    final loggedIn = await ApiClient().isLoggedIn();
    if (!loggedIn) return;

    final rol = await ApiClient().getRol();
    final userJson = await ApiClient().getUserJson();
    UserModel? user;
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        // Asegura campos mínimos requeridos por UserModel
        map['rol'] ??= rol ?? 'cliente';
        map['activo'] ??= true;
        user = UserModel.fromJson(map);
      } catch (_) {}
    }
    state = state.copyWith(rol: rol, user: user);
  }

  /// Retorna el rol en caso de éxito, null si hubo error.
  Future<String?> login(String celular, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient().dio.post(
        ApiConstants.login,
        data: {'celular': celular, 'password': password},
      );

      await ApiClient().saveTokens(
        access: res.data['access_token'],
        refresh: res.data['refresh_token'],
      );
      final rol = (res.data['rol'] as String?) ?? 'cliente';
      await ApiClient().saveRol(rol);

      final userMap = <String, dynamic>{
        'id': res.data['id'] ?? '',
        'nombre': res.data['nombre'] ?? '',
        'celular': res.data['celular'] ?? celular,
        'dni': res.data['dni'] ?? '',
        'rol': rol,
        'activo': true,
      };
      await ApiClient().saveUser(jsonEncode(userMap));

      state = state.copyWith(
        loading: false,
        user: UserModel.fromJson(userMap),
        rol: rol,
      );
      return rol;
    } catch (e) {
      final str = e.toString();
      String msg = 'Error al ingresar. Intenta de nuevo.';
      if (str.contains('401')) msg = 'Celular o contraseña incorrectos';
      if (str.contains('422')) msg = 'Formato inválido — revisa tu celular';
      if (str.contains('SocketException') ||
          str.contains('Connection refused') ||
          str.contains('Failed host lookup')) {
        msg = 'Sin conexión al servidor.\nVerifica que el backend esté activo.';
      }
      state = state.copyWith(loading: false, error: msg);
      return null;
    }
  }

  void setError(String msg) =>
      state = state.copyWith(error: msg);

  void clearError() =>
      state = state.copyWith(clearError: true);

  Future<void> logout() async {
    await ApiClient().logout();
    state = const AuthState();
  }
}

// ── Provider global ───────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
