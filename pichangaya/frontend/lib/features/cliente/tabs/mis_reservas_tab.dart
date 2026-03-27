import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a #sec-mis-reservas del HTML.
/// Contenido:
/// - mis-reservas-header: título + botón "+ Nueva" (→ va a tab Canchas)
/// - inner-tabs: "Reservas" | "Pagos"
///   Tab Reservas: lista de tarjetas por reserva con:
///     - nombre cancha, fecha, hora, estado (badge), precio, método pago
///     - botón "Ver detalle" y si está done → "Ver comprobante"
///   Tab Pagos: lista de pagos con:
///     - método, monto, estado (pagado/pendiente/rechazado), thumbnail voucher si existe
/// Solo muestra las reservas del cliente logueado (filtrado por clienteId)
class MisReservasTab extends StatelessWidget {
  const MisReservasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('📋 MisReservasTab — Reservas | Pagos del cliente\n(Implementar en Fase 2)',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.texto2)),
    );
  }
}
