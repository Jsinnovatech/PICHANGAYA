import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a #sec-pagar del HTML.
/// Contenido:
/// - pago-info-card: icono del método + instrucción + número/cuenta + titular + monto
///   (para efectivo: "Paga directamente en el local")
/// - voucher-upload: dropzone para subir foto del comprobante (image_picker)
///   - Preview de la imagen con botón "✕" para quitar
///   - Botón "✅ Enviar Voucher y Confirmar" (o "Confirmar Reserva (Pago en local)" si es efectivo)
/// Esta tab aparece después de seleccionar método de pago en el ReservaModal
class PagarTab extends StatelessWidget {
  const PagarTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('💳 PagarTab — info pago por método + upload voucher\n(Implementar en Fase 2)',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.texto2)),
    );
  }
}
