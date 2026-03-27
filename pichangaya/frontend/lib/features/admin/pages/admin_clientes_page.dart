import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a page-clientes del HTML.
/// Contenido: stats (total clientes, activos) + tabla
class AdminClientesPage extends StatelessWidget {
  const AdminClientesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          '👥 CLIENTES\nstats (total clientes, activos) + tabla\n\n(Implementar en Fase 3)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.texto2, height: 1.6),
        ),
      ),
    );
  }
}
