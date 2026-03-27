import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a page-timers del HTML.
/// Contenido: grid de timers activos (campo, cliente, countdown grande MM
class AdminTimersPage extends StatelessWidget {
  const AdminTimersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          '⏱️ TIMERS\ngrid de timers activos (campo, cliente, countdown grande MM\n\n(Implementar en Fase 3)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.texto2, height: 1.6),
        ),
      ),
    );
  }
}
