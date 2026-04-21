import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Página placeholder en el shell del super_admin para el tab "Canchas".
/// Las canchas se gestionan por local desde el tab "Locales".
class SuperAdminCanchasOverviewPage extends StatelessWidget {
  const SuperAdminCanchasOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚽', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Gestión de Canchas',
              style: TextStyle(color: AppColors.texto, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Las canchas se administran dentro de cada local.\nVe al tab "Locales", selecciona un local y toca "Canchas".',
              style: TextStyle(color: AppColors.texto2, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.verde.withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back, color: AppColors.verde, size: 16),
                SizedBox(width: 6),
                Text('Tab Locales → Canchas', style: TextStyle(color: AppColors.verde, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
