import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminAdminFormPage extends StatefulWidget {
  final VoidCallback onAdminCreado;
  const SuperAdminAdminFormPage({super.key, required this.onAdminCreado});

  @override
  State<SuperAdminAdminFormPage> createState() => _State();
}

class _State extends State<SuperAdminAdminFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _celularCtrl   = TextEditingController();
  final _dniCtrl       = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _celularCtrl.dispose();
    _dniCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await ApiClient().dio.post('/super-admin/admins', data: {
        'nombre':   _nombreCtrl.text.trim(),
        'celular':  _celularCtrl.text.trim(),
        'dni':      _dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });
      widget.onAdminCreado();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Admin creado exitosamente'),
          backgroundColor: AppColors.verde,
        ));
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ?? e.message ?? 'Error desconocido';
      setState(() { _error = msg; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        backgroundColor: AppColors.negro2,
        title: const Text('Nuevo Admin', style: TextStyle(color: AppColors.texto)),
        iconTheme: const IconThemeData(color: AppColors.texto),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _campo(
              controller: _nombreCtrl,
              label: 'Nombre completo',
              hint: 'Ej: Juan Quispe',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
            ),
            const SizedBox(height: 16),
            _campo(
              controller: _celularCtrl,
              label: 'Celular',
              hint: 'Ej: 955123456 (9 dígitos)',
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El celular es requerido';
                final limpio = v.replaceAll(RegExp(r'[\s\-]'), '').replaceAll('+51', '');
                if (!RegExp(r'^\d{9}$').hasMatch(limpio)) return 'Debe tener 9 dígitos';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _campo(
              controller: _dniCtrl,
              label: 'DNI (opcional)',
              hint: 'Ej: 45678901',
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(r'^\d{8}$').hasMatch(v.trim())) return 'El DNI debe tener 8 dígitos';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.texto),
              decoration: _inputDeco('Contraseña', 'Mínimo 8 caracteres con 1 número').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: AppColors.texto2),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'La contraseña es requerida';
                if (v.length < 8) return 'Mínimo 8 caracteres';
                if (!v.contains(RegExp(r'\d'))) return 'Debe contener al menos un número';
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rojo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.rojo.withOpacity(0.5)),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
              ),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: AppColors.negro,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                    : const Text('Crear Admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.texto),
        decoration: _inputDeco(label, hint),
        validator: validator,
      );

  InputDecoration _inputDeco(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: AppColors.texto2),
    hintStyle: TextStyle(color: AppColors.texto2.withOpacity(0.5)),
    filled: true,
    fillColor: AppColors.negro3,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borde),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.verde, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.rojo),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.rojo, width: 1.5),
    ),
  );
}
