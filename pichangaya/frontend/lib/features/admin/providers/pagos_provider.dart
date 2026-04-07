import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

// ── Estado ────────────────────────────────────────────────────
class AdminPagosState {
  final List<dynamic> pagos;
  final bool loading;
  final String? error;
  final String filtro;

  const AdminPagosState({
    this.pagos = const [],
    this.loading = false,
    this.error,
    this.filtro = 'pendiente',
  });

  AdminPagosState copyWith({
    List<dynamic>? pagos,
    bool? loading,
    String? error,
    bool clearError = false,
    String? filtro,
  }) =>
      AdminPagosState(
        pagos: pagos ?? this.pagos,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
        filtro: filtro ?? this.filtro,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class AdminPagosNotifier extends StateNotifier<AdminPagosState> {
  AdminPagosNotifier() : super(const AdminPagosState());

  Future<void> cargar({String? filtro}) async {
    final f = filtro ?? state.filtro;
    state = state.copyWith(loading: true, clearError: true, filtro: f);
    try {
      final params =
          f != 'todos' ? {'estado': f} : <String, dynamic>{};
      final res = await ApiClient().dio.get(
        ApiConstants.adminPagos,
        queryParameters: params,
      );
      state = state.copyWith(loading: false, pagos: res.data as List);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Error al cargar pagos');
    }
  }

  /// [accion]: 'aprobar' | 'rechazar'
  /// Retorna true si la operación fue exitosa.
  Future<bool> verificarPago(
    String pagoId,
    String accion, {
    String? motivo,
  }) async {
    try {
      await ApiClient().dio.patch(
        '/admin/pagos/$pagoId/verificar',
        data: {
          'accion': accion,
          if (motivo != null) 'motivo': motivo,
        },
      );
      await cargar();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final adminPagosProvider =
    StateNotifierProvider<AdminPagosNotifier, AdminPagosState>(
  (_) => AdminPagosNotifier(),
);
