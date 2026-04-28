import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminMediosPagoPage extends StatefulWidget {
  const SuperAdminMediosPagoPage({super.key});
  @override
  State<SuperAdminMediosPagoPage> createState() => _State();
}

class _State extends State<SuperAdminMediosPagoPage> {
  final _yapeCtrl = TextEditingController();
  final _bcpCtrl  = TextEditingController();
  final _bbvaCtrl = TextEditingController();

  String?    _qrBase64;
  Uint8List? _qrBytes;
  bool   _loading = true;
  bool   _saving  = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _yapeCtrl.dispose();
    _bcpCtrl.dispose();
    _bbvaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get('/super-admin/medios-pago');
      final d = res.data as Map<String, dynamic>;
      _yapeCtrl.text = d['yape_numero']      ?? '';
      _bcpCtrl.text  = d['cuenta_bcp']       ?? '';
      _bbvaCtrl.text = d['cuenta_bbva']      ?? '';
      _qrBase64      = d['qr_imagen_base64'] as String?;
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = 'Error al cargar configuración'; _loading = false; });
    }
  }

  Future<void> _elegirQr() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      setState(() => _error = 'La imagen no debe superar 2 MB');
      return;
    }
    final ext  = picked.name.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'png' : 'jpeg';
    setState(() {
      _qrBytes  = bytes;
      _qrBase64 = 'data:image/$mime;base64,${base64Encode(bytes)}';
      _error    = null;
    });
  }

  Future<void> _guardar() async {
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      final body = <String, dynamic>{
        'yape_numero':      _yapeCtrl.text.trim().isEmpty ? null : _yapeCtrl.text.trim(),
        'cuenta_bcp':       _bcpCtrl.text.trim().isEmpty  ? null : _bcpCtrl.text.trim(),
        'cuenta_bbva':      _bbvaCtrl.text.trim().isEmpty ? null : _bbvaCtrl.text.trim(),
        'qr_imagen_base64': _qrBase64,
      };
      await ApiClient().dio.put('/super-admin/medios-pago', data: body);
      setState(() { _success = 'Configuración guardada correctamente'; _saving = false; });
    } catch (e) {
      setState(() { _error = 'Error al guardar. Intenta de nuevo.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.amarillo));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Configura tus medios de pago',
            style: TextStyle(color: AppColors.texto, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Estos datos se mostrarán a los admins al pagar su suscripción.',
          style: TextStyle(color: AppColors.texto2, fontSize: 13),
        ),
        const SizedBox(height: 20),

        _label('Número Yape / Plin'),
        const SizedBox(height: 6),
        _campo(_yapeCtrl, '999 999 999', TextInputType.phone),
        const SizedBox(height: 16),

        _label('Cuenta BCP (CCI o número)'),
        const SizedBox(height: 6),
        _campo(_bcpCtrl, 'Ej: 19300000000000', TextInputType.text),
        const SizedBox(height: 16),

        _label('Cuenta BBVA (CCI o número)'),
        const SizedBox(height: 6),
        _campo(_bbvaCtrl, 'Ej: 01100000000000', TextInputType.text),
        const SizedBox(height: 20),

        _label('Imagen QR de Yape / Plin'),
        const SizedBox(height: 10),
        _qrSection(),
        const SizedBox(height: 24),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (_success != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.verdeGlow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.verde.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.verde, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_success!, style: const TextStyle(color: AppColors.verde, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amarillo,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Guardar Cambios',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: AppColors.texto2, fontSize: 13, fontWeight: FontWeight.w500));

  Widget _campo(TextEditingController ctrl, String hint, TextInputType type) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: AppColors.texto),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.texto2),
          filled: true,
          fillColor: AppColors.negro2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borde),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borde),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.amarillo),
          ),
        ),
      );

  Widget _qrSection() {
    Uint8List? previewBytes = _qrBytes;
    if (previewBytes == null && _qrBase64 != null && _qrBase64!.contains(',')) {
      try {
        previewBytes = base64Decode(_qrBase64!.split(',').last);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (previewBytes != null) ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(previewBytes, width: 180, height: 180, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() { _qrBytes = null; _qrBase64 = null; }),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
              label: const Text('Quitar imagen', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          ),
        ] else ...[
          const Center(child: Icon(Icons.qr_code_2, color: AppColors.texto2, size: 64)),
          const SizedBox(height: 8),
          const Center(child: Text('Sin imagen QR', style: TextStyle(color: AppColors.texto2, fontSize: 13))),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _elegirQr,
            icon: const Icon(Icons.upload, size: 16),
            label: Text(previewBytes != null ? 'Cambiar QR' : 'Subir imagen QR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amarillo,
              side: const BorderSide(color: AppColors.amarillo),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ]),
    );
  }
}
