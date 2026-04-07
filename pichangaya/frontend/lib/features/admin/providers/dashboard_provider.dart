import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

// ── Estado ────────────────────────────────────────────────────
class DashboardState {
  final Map<String, dynamic>? stats;
  final List<dynamic> ultimasReservas;
  final bool loading;
  final String? error;

  const DashboardState({
    this.stats,
    this.ultimasReservas = const [],
    this.loading = false,
    this.error,
  });

  DashboardState copyWith({
    Map<String, dynamic>? stats,
    List<dynamic>? ultimasReservas,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      DashboardState(
        stats: stats ?? this.stats,
        ultimasReservas: ultimasReservas ?? this.ultimasReservas,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
      );

  // Helpers de acceso rápido a stats
  int get reservasHoy => (stats?['reservas_hoy'] as num?)?.toInt() ?? 0;
  int get reservasPendientes =>
      (stats?['reservas_pendientes'] as num?)?.toInt() ?? 0;
  double get ingresosHoy =>
      (stats?['ingresos_hoy'] as num?)?.toDouble() ?? 0.0;
  int get totalClientes => (stats?['total_clientes'] as num?)?.toInt() ?? 0;
  int get pagosPendientes =>
      (stats?['pagos_pendientes'] as num?)?.toInt() ?? 0;
  int get reservasConfirmadas => reservasHoy - reservasPendientes;
}

// ── Notifier ──────────────────────────────────────────────────
class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  Future<void> cargar() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminDashboard);
      state = state.copyWith(
        loading: false,
        stats: res.data['stats'] as Map<String, dynamic>?,
        ultimasReservas: res.data['ultimas_reservas'] as List? ?? [],
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Error al cargar dashboard',
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final adminDashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (_) => DashboardNotifier(),
);
