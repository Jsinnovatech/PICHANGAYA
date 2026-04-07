import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

// ── Estado ────────────────────────────────────────────────────
class AdminClientesState {
  final List<dynamic> clientes;
  final List<dynamic> filtrados;
  final bool loading;
  final String? error;
  final String query;

  const AdminClientesState({
    this.clientes = const [],
    this.filtrados = const [],
    this.loading = false,
    this.error,
    this.query = '',
  });

  AdminClientesState copyWith({
    List<dynamic>? clientes,
    List<dynamic>? filtrados,
    bool? loading,
    String? error,
    bool clearError = false,
    String? query,
  }) =>
      AdminClientesState(
        clientes: clientes ?? this.clientes,
        filtrados: filtrados ?? this.filtrados,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
        query: query ?? this.query,
      );

  int get total => clientes.length;
  int get activos => clientes.where((c) => c['activo'] == true).length;
  int get inactivos => total - activos;
}

// ── Notifier ──────────────────────────────────────────────────
class AdminClientesNotifier extends StateNotifier<AdminClientesState> {
  AdminClientesNotifier() : super(const AdminClientesState());

  Future<void> cargar() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminClientes);
      final lista = res.data as List;
      state = state.copyWith(
        loading: false,
        clientes: lista,
        filtrados: lista,
        query: '',
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Error al cargar clientes',
      );
    }
  }

  void filtrar(String query) {
    final q = query.toLowerCase().trim();
    final filtrados = q.isEmpty
        ? state.clientes
        : state.clientes
            .where((c) =>
                (c['nombre'] ?? '').toLowerCase().contains(q) ||
                (c['celular'] ?? '').contains(q) ||
                (c['dni'] ?? '').contains(q))
            .toList();
    state = state.copyWith(filtrados: filtrados, query: query);
  }

  /// Retorna true si el toggle fue exitoso.
  Future<bool> toggleCliente(String id) async {
    try {
      await ApiClient().dio.patch('/admin/clientes/$id/toggle');
      await cargar();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final adminClientesProvider =
    StateNotifierProvider<AdminClientesNotifier, AdminClientesState>(
  (_) => AdminClientesNotifier(),
);
