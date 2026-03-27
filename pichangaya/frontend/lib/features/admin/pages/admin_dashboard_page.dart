import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a page-dashboard del HTML.
/// Contenido: stats-grid (reservas hoy, ingresos, clientes, partidos activos) + tabla últimas reservas (cliente, cancha, fecha, hora, estado, acciones)
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          '📊 DASHBOARD\nstats-grid (reservas hoy, ingresos, clientes, partidos activos) + tabla últimas reservas (cliente, cancha, fecha, hora, estado, acciones)\n\n(Implementar en Fase 3)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.texto2, height: 1.6),
        ),
      ),
    );
  }
}
