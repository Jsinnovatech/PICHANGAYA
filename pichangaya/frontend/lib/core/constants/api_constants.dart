class ApiConstants {
  // ── Solo localhost por ahora ──────────────────────────────────
  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const String wsTimers = 'ws://localhost:8000/ws/timers';

  // ── Auth ──────────────────────────────────────────────────────
  static const String register = '/auth/register';
  static const String login    = '/auth/login';
  static const String refresh  = '/auth/refresh';
  static const String me       = '/auth/me';

  // ── Locales + Canchas ─────────────────────────────────────────
  static const String locales        = '/locales';
  static const String disponibilidad = '/canchas/{id}/disponibilidad';

  // ── Reservas ─────────────────────────────────────────────────
  static const String reservas    = '/reservas';
  static const String misReservas = '/reservas/mis-reservas';

  // ── Pagos ─────────────────────────────────────────────────────
  static const String pagoVoucher = '/pagos/{id}/voucher';

  // ── Admin ─────────────────────────────────────────────────────
  static const String adminReservas      = '/admin/reservas';
  static const String adminPagos         = '/admin/pagos';
  static const String adminClientes      = '/admin/clientes';
  static const String adminDashboard     = '/admin/dashboard';
  static const String adminVerificarPago = '/admin/pagos/{id}/verificar';

  // ── Suscripción ───────────────────────────────────────────────
  static const String miSuscripcion    = '/suscripcion/mi-suscripcion';
  static const String pagarSuscripcion = '/suscripcion/pagar';

  // ── Super Admin ───────────────────────────────────────────────
  static const String superAdminDashboard     = '/super-admin/dashboard';
  static const String superAdminSuscripciones = '/super-admin/suscripciones-pendientes';

  // ── Notificaciones ────────────────────────────────────────────
  static const String notificaciones = '/notificaciones';
  static const String noLeidas       = '/notificaciones/no-leidas';
}
