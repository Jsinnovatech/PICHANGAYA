import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/models/local_model.dart';

// ── Estado ────────────────────────────────────────────────────
class LocalesState {
  final List<LocalModel> locales;
  final bool loading;
  final String? error;
  final double radio;
  final double? lat;
  final double? lng;

  const LocalesState({
    this.locales = const [],
    this.loading = false,
    this.error,
    this.radio = 1.0,
    this.lat,
    this.lng,
  });

  LocalesState copyWith({
    List<LocalModel>? locales,
    bool? loading,
    String? error,
    bool clearError = false,
    double? radio,
    double? lat,
    double? lng,
  }) =>
      LocalesState(
        locales: locales ?? this.locales,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
        radio: radio ?? this.radio,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class LocalesNotifier extends StateNotifier<LocalesState> {
  LocalesNotifier() : super(const LocalesState());

  Future<void> cargar({
    required double lat,
    required double lng,
    double? radio,
  }) async {
    final r = radio ?? state.radio;
    state = state.copyWith(
      loading: true,
      clearError: true,
      lat: lat,
      lng: lng,
      radio: r,
    );
    try {
      final res = await ApiClient().dio.get(
        ApiConstants.locales,
        queryParameters: {'lat': lat, 'lng': lng, 'radio': r},
      );
      state = state.copyWith(
        loading: false,
        locales: (res.data as List).map((j) => LocalModel.fromJson(j)).toList(),
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Error al cargar locales');
    }
  }

  /// Cambia el radio y recarga si ya hay posición disponible.
  void setRadio(double radio) {
    if (state.lat != null && state.lng != null) {
      cargar(lat: state.lat!, lng: state.lng!, radio: radio);
    } else {
      state = state.copyWith(radio: radio);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final localesProvider = StateNotifierProvider<LocalesNotifier, LocalesState>(
  (_) => LocalesNotifier(),
);
