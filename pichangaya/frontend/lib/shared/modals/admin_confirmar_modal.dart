import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a modal-admin-confirmar del HTML.
/// Muestra detalle de la reserva y los botones:
/// ✅ Confirmar → PATCH /admin/reservas/{id}/estado {estado: 'confirmed'}
/// ❌ Cancelar  → PATCH /admin/reservas/{id}/estado {estado: 'canceled'}
class AdminConfirmarModal extends StatelessWidget {
  const AdminConfirmarModal({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    child: const Center(child: Text('AdminConfirmarModal — en construcción', style: TextStyle(color: AppColors.texto2))),
  );
}
