import 'package:flutter/foundation.dart';

class ApiConstants {
  // Ambiente controlado por dart-define:
  //   --dart-define=API_ENV=development  → backend local (localhost)
  //   (sin define / producción)          → Railway
  static const String _env = String.fromEnvironment('API_ENV', defaultValue: 'production');

  static const String _railwayUrl = 'https://pichangaya-production-0eb7.up.railway.app';

  // ── URL base según ambiente ──────────────────────────────────
  // development + web   → http://localhost:8000/api/v1
  // development + móvil → http://10.0.2.2:8000/api/v1
  // production          → Railway
  static String get baseUrl {
    if (_env == 'development') {
      return kIsWeb
          ? 'http://localhost:8000/api/v1'
          : 'http://10.0.2.2:8000/api/v1';
    }
    return '$_railwayUrl/api/v1';
  }

  static String get wsBaseUrl {
    if (_env == 'development') {
      return kIsWeb ? 'ws://localhost:8000' : 'ws://10.0.2.2:8000';
    }
    return 'wss://pichangaya-production-0eb7.up.railway.app';
  }

  static String get wsTimers => '$wsBaseUrl/ws/timers';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // Locales + Canchas
  static const String locales = '/locales';
  static const String disponibilidad = '/canchas/{id}/disponibilidad';

  // Reservas
  static const String reservas = '/reservas';
  static const String misReservas = '/reservas/mis-reservas';

  // Pagos
  static const String pagoVoucher = '/pagos/{id}/voucher';

  // Admin
  static const String adminReservas = '/admin/reservas';
  static const String adminPagos = '/admin/pagos';
  static const String adminClientes = '/admin/clientes';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminVerificarPago = '/admin/pagos/{id}/verificar';
  static const String adminLocales  = '/admin/locales';
  static const String adminCanchas  = '/admin/canchas';
  static const String adminHorarios = '/admin/horarios';
  static const String adminBloqueos = '/admin/bloqueos';
  static const String datosPago       = '/locales/configuracion/pagos';
  static const String mediosPagoLocal = '/locales/{id}/medios-pago';

  // Admin Medios de Pago
  static const String adminMediosPago = '/admin/medios-pago';

  // Suscripcion
  static const String miSuscripcion = '/suscripcion/mi-suscripcion';
  static const String pagarSuscripcion = '/suscripcion/pagar';

  // Super Admin
  static const String superAdminDashboard = '/super-admin/dashboard';
  static const String superAdminSuscripciones =
      '/super-admin/suscripciones-pendientes';
  static const String superAdminHistorialPagos   = '/super-admin/historial-pagos';
  static const String superAdminAlertasVenc      = '/super-admin/alertas-vencimiento';
  static const String superAdminToggleAdmin      = '/super-admin/admins';
  static const String superAdminPlanes          = '/super-admin/planes';
  static const String superAdminReportes        = '/super-admin/reportes';
  static const String superAdminReservas        = '/super-admin/reservas';
  static const String superAdminAdmins         = '/super-admin/admins';
  static const String superAdminLocales        = '/super-admin/locales';
  static const String superAdminCanchas        = '/super-admin/canchas';

  // Notificaciones
  static const String notificaciones = '/notificaciones';
  static const String noLeidas = '/notificaciones/no-leidas';
}
