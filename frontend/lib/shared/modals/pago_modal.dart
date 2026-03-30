import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a modal-pago del HTML.
/// Contenido:
/// - pago-info-card: icono, instrucción "Envía el pago a:" / "Paga en el local",
///   número/cuenta, titular, monto en verde grande
/// - voucher-upload: dropzone "📸 Toca para subir tu comprobante"
///   → usa image_picker → preview con botón "✕" quitar
///   (oculto si método = efectivo)
/// - Botón "✅ Enviar Voucher y Confirmar" / "✅ Confirmar Reserva (Pago en local)"
///   → POST /reservas + POST /pagos/{id}/voucher
class PagoModal extends StatelessWidget {
  const PagoModal({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    child: const Center(child: Text('PagoModal — en construcción', style: TextStyle(color: AppColors.texto2))),
  );
}
