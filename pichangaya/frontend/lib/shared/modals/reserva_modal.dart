import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a modal-reserva del HTML.
/// Contenido:
/// - reserva-summary: resumen readonly (cancha, local, fecha, hora, precio)
/// - reserva-form-fields: nombre + teléfono + DNI/RUC (pre-relleno si está logueado, opacidad 0.6)
/// - Selector método de pago: Yape 📱 | Plin 📲 | Transferencia 🏦 | Efectivo 💵
/// - Botón "💰 Proceder al Pago" → cierra este modal, abre PagoModal
class ReservaModal extends StatelessWidget {
  const ReservaModal({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.negro2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    builder: (_) => const ReservaModal(),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    child: const Center(child: Text('ReservaModal — en construcción', style: TextStyle(color: AppColors.texto2))),
  );
}
