import 'package:flutter/foundation.dart';

class ApiConstants {
  // Detecta automaticamente si es web (Chrome) o Android emulator
  static const String _railwayUrl = 'https://pichangaya-production-0eb7.up.railway.app';

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    return 'http://10.0.2.2:8000/api/v1';
    // PRODUCCIÓN: return '$_railwayUrl/api/v1';
  }

  static String get wsTimers {
    if (kIsWeb) return 'ws://localhost:8000/ws/timers';
    return 'ws://10.0.2.2:8000/ws/timers';
    // PRODUCCIÓN: return 'wss://pichangaya-production-0eb7.up.railway.app/ws/timers';
  }

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
