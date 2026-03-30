import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'dart:convert';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});
  @override
  State<ClientRegisterScreen> createState() => _State();
}

class _State extends State<ClientRegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _celCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'Ingresa tu nombre completo';
      });
      return;
    }
    if (!_emailCtrl.text.contains('@')) {
      setState(() {
        _error = 'Ingresa un correo válido';
      });
      return;
    }
    if (_celCtrl.text.trim().length != 9) {
      setState(() {
        _error = 'El celular debe tener 9 dígitos';
      });
      return;
    }
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() {
        _error = 'Las contraseñas no coinciden';
      });
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() {
        _error = 'Mínimo 6 caracteres';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.post(ApiConstants.register, data: {
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'celular': _celCtrl.text.trim(),
        'dni': _dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      await ApiClient().saveTokens(
          access: res.data['access_token'], refresh: res.data['refresh_token']);
      await ApiClient().saveRol(res.data['rol']);
      await ApiClient().saveUser(jsonEncode({
        'nombre': res.data['nombre'] ?? _nombreCtrl.text.trim(),
        'email': res.data['email'] ?? _emailCtrl.text.trim(),
        'celular': res.data['celular'] ?? _celCtrl.text.trim(),
        'dni': _dniCtrl.text.trim(),
      }));
      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      setState(() {
        _error =
            'Error en el registro. El correo o celular ya puede estar registrado.';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Widget _field(String label, TextEditingController ctrl,
          {TextInputType? type,
          bool obscure = false,
          String? hint,
          int? maxLen}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.texto2,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: type,
          maxLength: maxLen,
          decoration: InputDecoration(hintText: hint, counterText: ''),
        ),
        const SizedBox(height: 14),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.negro,
        body: Center(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borde),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Column(children: [
                    Image.asset('assets/images/logo_pichangaya.png',
                        width: 180, fit: BoxFit.contain),
                    const SizedBox(height: 6),
                    const Text('Crear cuenta nueva',
                        style:
                            TextStyle(color: AppColors.texto2, fontSize: 14)),
                  ]),
                  const SizedBox(height: 24),

                  // Error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.rojo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.rojo.withOpacity(0.4))),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.rojo, fontSize: 13)),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Nombre
                  _field('NOMBRE COMPLETO', _nombreCtrl,
                      hint: 'Ej: Juan Pérez'),

                  // Email — campo principal
                  _field('CORREO ELECTRÓNICO', _emailCtrl,
                      type: TextInputType.emailAddress,
                      hint: 'ejemplo@gmail.com'),

                  // Celular
                  const Text('CELULAR',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.texto2,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.negro3,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8)),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.borde)),
                      ),
                      child: const Text('🇵🇪 +51',
                          style:
                              TextStyle(color: AppColors.texto2, fontSize: 14)),
                    ),
                    Expanded(
                        child: TextField(
                      controller: _celCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 9,
                      decoration: const InputDecoration(
                          hintText: '999 888 777',
                          counterText: '',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(8)),
                              borderSide: BorderSide(color: AppColors.borde))),
                    )),
                  ]),
                  const SizedBox(height: 14),

                  _field('DNI (opcional)', _dniCtrl,
                      hint: '45678901', maxLen: 8),
                  _field('CONTRASEÑA', _passCtrl,
                      obscure: true, hint: 'Mínimo 6 caracteres'),
                  _field('CONFIRMAR CONTRASEÑA', _pass2Ctrl,
                      obscure: true, hint: 'Repite tu contraseña'),

                  // Botón
                  ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.negro))
                        : const Text('✅  CREAR CUENTA',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                  ),

                  TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('¿Ya tienes cuenta? Inicia sesión',
                          style: TextStyle(color: AppColors.texto2))),
                  TextButton(
                      onPressed: () => context.go('/entry'),
                      child: const Text('← Volver',
                          style: TextStyle(color: AppColors.texto2))),
                ]),
          ),
        )),
      );
}
