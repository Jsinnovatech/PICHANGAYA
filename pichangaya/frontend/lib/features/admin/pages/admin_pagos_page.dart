import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a page-pagos del HTML.
/// Contenido: stats (total pagos, monto verificado, pendientes) + cards de pago con
class AdminPagosPage extends StatelessWidget {
  const AdminPagosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          '💳 PAGOS\nstats (total pagos, monto verificado, pendientes) + cards de pago con\n\n(Implementar en Fase 3)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.texto2, height: 1.6),
        ),
      ),
    );
  }
}
