import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a page-canchas del HTML.
/// Contenido: grid de canchas (card con nombre, local, capacidad, superficie, precio/hr, badge activa/inactiva, botones Activar/Desactivar) + botón Nueva Cancha → AddCanchaModal
class AdminCanchasPage extends StatelessWidget {
  const AdminCanchasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          '🏟️ CANCHAS\ngrid de canchas (card con nombre, local, capacidad, superficie, precio/hr, badge activa/inactiva, botones Activar/Desactivar) + botón Nueva Cancha → AddCanchaModal\n\n(Implementar en Fase 3)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.texto2, height: 1.6),
        ),
      ),
    );
  }
}
