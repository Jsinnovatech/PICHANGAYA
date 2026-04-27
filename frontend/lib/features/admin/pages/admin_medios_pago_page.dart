import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class AdminMediosPagoPage extends StatefulWidget {
  const AdminMediosPagoPage({super.key});
  @override
  State<AdminMediosPagoPage> createState() => _State();
}

class _State extends State<AdminMediosPagoPage> {
  final _yapeCtrl = TextEditingController();
  final _bcpCtrl  = TextEditingController();
  final _bbvaCtrl = TextEditingController();

  String? _qrBase64;   // base64 data URL: "data:image/png;base64,..."
  bool _loading  = true;
  bool _saving   = false;
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
      final res = await ApiClient().dio.get('/admin/medios-pago');
      final d = res.data as Map<String, dynamic>;
      _yapeCtrl.text = d['yape_numero'] ?? '';
      _bcpCtrl.text  = d['cuenta_bcp']  ?? '';
      _bbvaCtrl.text = d['cuenta_bbva'] ?? '';
      setState(() {
        _qrBase64 = d['qr_imagen_base64'];
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar configuración'; _loading = false; });
    }
  }

  Future<void> _pickQr() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);
      final ext  = picked.name.split('.').last.toLowerCase();
      final mime = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png';
      setState(() => _qrBase64 = 'data:$mime;base64,$b64');
    } catch (e) {
      setState(() => _error = 'No se pudo seleccionar imagen');
    }
  }

  Future<void> _guardar() async {
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      await ApiClient().dio.put('/admin/medios-pago', data: {
        'yape_numero':      _yapeCtrl.text.trim().isEmpty ? null : _yapeCtrl.text.trim(),
        'qr_imagen_base64': _qrBase64,
        'cuenta_bcp':       _bcpCtrl.text.trim().isEmpty  ? null : _bcpCtrl.text.trim(),
        'cuenta_bbva':      _bbvaCtrl.text.trim().isEmpty ? null : _bbvaCtrl.text.trim(),
      });
      setState(() { _success = 'Medios de pago guardados'; _saving = false; });
    } catch (e) {
      String msg = 'Error al guardar';
      if (e is DioException) msg = e.response?.data?['detail']?.toString() ?? msg;
      setState(() { _error = msg; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header info ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.azul.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.azul.withOpacity(0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.azul, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Configura los métodos de pago que verán tus clientes al realizar una reserva.',
              style: TextStyle(color: AppColors.azul, fontSize: 13),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Sección Yape / Plin ─────────────────────────────────
        _seccionTitulo('📱 Yape / Plin'),
        const SizedBox(height: 12),

        // QR Image
        _label('Imagen QR (Yape o Plin)'),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Vista previa del QR
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.negro,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borde),
            ),
            child: _qrBase64 != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildQrImage(),
                  )
                : const Center(
                    child: Icon(Icons.qr_code_2, color: AppColors.borde, size: 48),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: _pickQr,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(_qrBase64 != null ? 'Cambiar QR' : 'Subir QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.negro2,
                  foregroundColor: AppColors.verde,
                  side: const BorderSide(color: AppColors.verde),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              if (_qrBase64 != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => setState(() => _qrBase64 = null),
                  icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.rojo),
                  label: const Text('Eliminar QR', style: TextStyle(color: AppColors.rojo, fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'Soporta PNG o JPG.\nSe mostrará a clientes al pagar.',
                style: TextStyle(color: AppColors.texto2, fontSize: 11),
              ),
            ],
          )),
        ]),
        const SizedBox(height: 16),

        _label('Número Yape (o Plin)'),
        const SizedBox(height: 8),
        _campo(_yapeCtrl, '📱 Ej: 999 123 456', TextInputType.phone),
        const SizedBox(height: 24),

        // ── Sección Cuentas bancarias ───────────────────────────
        _seccionTitulo('🏦 Cuentas Bancarias'),
        const SizedBox(height: 12),

        _label('Número de cuenta BCP'),
        const SizedBox(height: 8),
        _campo(_bcpCtrl, 'Ej: 191-12345678-0-12', TextInputType.text),
        const SizedBox(height: 16),

        _label('Número de cuenta BBVA'),
        const SizedBox(height: 8),
        _campo(_bbvaCtrl, 'Ej: 0011-0108-0100-000000', TextInputType.text),
        const SizedBox(height: 28),

        // ── Feedback ────────────────────────────────────────────
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.rojo.withOpacity(0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
          ),

        if (_success != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.verde.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.verde, size: 16),
              const SizedBox(width: 8),
              Text(_success!, style: const TextStyle(color: AppColors.verde, fontSize: 13)),
            ]),
          ),

        // ── Botón guardar ────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('💾 Guardar cambios',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildQrImage() {
    final qr = _qrBase64!;
    if (qr.startsWith('data:')) {
      final commaIdx = qr.indexOf(',');
      if (commaIdx != -1) {
        final bytes = base64Decode(qr.substring(commaIdx + 1));
        return Image.memory(bytes, fit: BoxFit.contain);
      }
    }
    // URL directa
    return Image.network(qr, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.borde));
  }

  Widget _seccionTitulo(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.texto,
      fontWeight: FontWeight.w700,
      fontSize: 15,
      letterSpacing: 0.3,
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(color: AppColors.texto2, fontSize: 13),
  );

  Widget _campo(TextEditingController ctrl, String hint, TextInputType tipo) =>
    TextField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(color: AppColors.texto),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.borde, fontSize: 13),
        filled: true,
        fillColor: AppColors.negro,
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
          borderSide: const BorderSide(color: AppColors.verde),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}
