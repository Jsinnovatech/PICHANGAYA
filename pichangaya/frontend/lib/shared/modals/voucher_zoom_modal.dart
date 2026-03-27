import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a modal-voucher-zoom del HTML.
/// Muestra imagen del voucher a pantalla completa.
/// Tap fuera o en X → cierra.
class VoucherZoomModal extends StatelessWidget {
  final String imageUrl;
  const VoucherZoomModal({super.key, required this.imageUrl});

  static Future<void> show(BuildContext context, String url) =>
    showDialog(context: context, builder: (_) => VoucherZoomModal(imageUrl: url));

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.negro2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('VOUCHER', style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w700)),
          IconButton(icon: const Icon(Icons.close, color: AppColors.texto2), onPressed: () => Navigator.pop(context)),
        ]),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ]),
    ),
  );
}
