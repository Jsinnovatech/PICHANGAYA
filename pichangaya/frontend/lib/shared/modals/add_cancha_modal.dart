import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a modal-add-cancha del HTML.
/// Formulario nueva cancha:
/// - Nombre (text)
/// - Local (dropdown de locales existentes)
/// - Capacidad (número, default 10)
/// - Precio/hora en S/. (número)
/// - Superficie (dropdown: Gras Sintético | Piso Madera | Cemento)
/// Botón "+ Agregar" → POST /admin/canchas
class AddCanchaModal extends StatelessWidget {
  const AddCanchaModal({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    child: const Center(child: Text('AddCanchaModal — en construcción', style: TextStyle(color: AppColors.texto2))),
  );
}
