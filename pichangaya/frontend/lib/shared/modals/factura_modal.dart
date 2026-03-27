import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a modal-factura del HTML.
/// Muestra el comprobante electrónico:
/// - RUC empresa + serie/número
/// - Cliente, base imponible, IGV 18%, total
/// - Estado SUNAT: si ya tiene serie → badge verde ✅ B001-00001
///   si no → botón "📤 Emitir a SUNAT" → POST /admin/comprobantes/{id}/emitir
class FacturaModal extends StatelessWidget {
  const FacturaModal({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    child: const Center(child: Text('FacturaModal — en construcción', style: TextStyle(color: AppColors.texto2))),
  );
}
