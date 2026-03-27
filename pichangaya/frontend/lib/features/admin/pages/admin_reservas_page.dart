import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a page-reservas del HTML.
/// Contenido: filtro de estado (Todos/Pendientes/Activas/Completadas/Canceladas) + tabla con columnas
class AdminReservasPage extends StatelessWidget {
  const AdminReservasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          '📋 RESERVAS\nfiltro de estado (Todos/Pendientes/Activas/Completadas/Canceladas) + tabla con columnas\n\n(Implementar en Fase 3)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.texto2, height: 1.6),
        ),
      ),
    );
  }
}
