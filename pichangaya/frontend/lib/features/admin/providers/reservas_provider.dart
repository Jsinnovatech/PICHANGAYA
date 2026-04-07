import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

// ── Estado ────────────────────────────────────────────────────
class AdminReservasState {
  final List<dynamic> reservas;
  final bool loading;
  final String? error;
  final String filtroEstado;

  const AdminReservasState({
    this.reservas = const [],
    this.loading = false,
    this.error,
    this.filtroEstado = 'todos',
  });

  AdminReservasState copyWith({
    List<dynamic>? reservas,
    bool? loading,
    String? error,
    bool clearError = false,
    String? filtroEstado,
  }) =>
      AdminReservasState(
        reservas: reservas ?? this.reservas,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
        filtroEstado: filtroEstado ?? this.filtroEstado,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class AdminReservasNotifier extends StateNotifier<AdminReservasState> {
  AdminReservasNotifier() : super(const AdminReservasState());

  Future<void> cargar({String? filtro}) async {
    final f = filtro ?? state.filtroEstado;
    state = state.copyWith(loading: true, clearError: true, filtroEstado: f);
    try {
      final params =
          f != 'todos' ? {'estado': f} : <String, dynamic>{};
      final res = await ApiClient().dio.get(
        ApiConstants.adminReservas,
        queryParameters: params,
      );
      state = state.copyWith(loading: false, reservas: res.data as List);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Error al cargar reservas',
      );
    }
  }

  /// Retorna true si el cambio fue exitoso.
  Future<bool> cambiarEstado(String reservaId, String nuevoEstado) async {
    try {
      await ApiClient().dio.patch(
        '/admin/reservas/$reservaId/estado',
        data: {'estado': nuevoEstado},
      );
      await cargar();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final adminReservasProvider =
    StateNotifierProvider<AdminReservasNotifier, AdminReservasState>(
  (_) => AdminReservasNotifier(),
);
