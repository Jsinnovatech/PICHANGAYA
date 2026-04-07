import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/models/reserva_model.dart';

// ── Estado ────────────────────────────────────────────────────
class ReservasClienteState {
  final List<ReservaModel> reservas;
  final bool loading;
  final String? error;

  const ReservasClienteState({
    this.reservas = const [],
    this.loading = false,
    this.error,
  });

  ReservasClienteState copyWith({
    List<ReservaModel>? reservas,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      ReservasClienteState(
        reservas: reservas ?? this.reservas,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class ReservasClienteNotifier extends StateNotifier<ReservasClienteState> {
  ReservasClienteNotifier() : super(const ReservasClienteState());

  Future<void> cargar() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient().dio.get(ApiConstants.misReservas);
      state = state.copyWith(
        loading: false,
        reservas:
            (res.data as List).map((j) => ReservaModel.fromJson(j)).toList(),
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Error al cargar reservas',
      );
    }
  }

  /// Retorna true si la cancelación fue exitosa.
  Future<bool> cancelar(String id) async {
    try {
      await ApiClient().dio.patch('/reservas/$id/cancelar');
      await cargar();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final reservasClienteProvider =
    StateNotifierProvider<ReservasClienteNotifier, ReservasClienteState>(
  (_) => ReservasClienteNotifier(),
);
