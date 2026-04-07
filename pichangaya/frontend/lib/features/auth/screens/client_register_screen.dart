import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'dart:convert';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});
  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _celCtrl    = TextEditingController();
  final _dniCtrl    = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _pass2Ctrl  = TextEditingController();
  bool  _loading    = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _celCtrl.dispose();
    _dniCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final nombre  = _nombreCtrl.text.trim();
    final celular = _celCtrl.text.trim()
        .replaceAll('+51', '').replaceAll(' ', '').replaceAll('-', '');
    final pass    = _passCtrl.text;
    final pass2   = _pass2Ctrl.text;
    final dni     = _dniCtrl.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresa tu nombre completo'); return;
    }
    if (celular.length != 9 || !celular.startsWith('9')) {
      setState(() => _error = 'El celular debe tener 9 dígitos y empezar con 9'); return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'La contraseña debe tener mínimo 6 caracteres'); return;
    }
    if (pass != pass2) {
      setState(() => _error = 'Las contraseñas no coinciden'); return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final res = await ApiClient().dio.post(ApiConstants.register, data: {
        'nombre':   nombre,
        'celular':  celular,
        'password': pass,
        if (dni.isNotEmpty) 'dni': dni,
      });

      await ApiClient().saveTokens(
        access:  res.data['access_token'],
        refresh: res.data['refresh_token'],
      );
      await ApiClient().saveRol(res.data['rol']);
      await ApiClient().saveUser(jsonEncode({
        'nombre':  res.data['nombre']  ?? nombre,
        'celular': res.data['celular'] ?? celular,
        'email':   '',
        'dni':     dni,
      }));

      if (!mounted) return;
      context.go('/home');

    } catch (e) {
      String msg = 'Error en el registro. Intenta de nuevo.';
      final str = e.toString();
      if (str.contains('400')) msg = 'El celular ya está registrado';
      if (str.contains('422')) msg = 'Datos inválidos — revisa el formulario';
      if (str.contains('SocketException') ||
          str.contains('Connection refused') ||
          str.contains('Failed host lookup')) {
        msg = 'Sin conexión al servidor.\nVerifica que el backend esté activo.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _campo(String label, TextEditingController ctrl, {
    TextInputType? tipo,
    bool obscure = false,
    String? hint,
    int? maxLen,
    Widget? suffix,
  }) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: const TextStyle(
          fontSize: 11, color: AppColors.texto2,
          letterSpacing: 0.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: tipo,
        maxLength: maxLen,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          suffixIcon: suffix,
          filled: true,
          fillColor: AppColors.negro3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borde)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borde)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.verde, width: 1.5)),
        ),
      ),
      const SizedBox(height: 14),
    ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Logo ─────────────────────────────────────────
              Center(child: Column(children: [
                Image.asset('assets/images/logo_pichangaya.png', height: 70),
                const SizedBox(height: 6),
                const Text('PICHANGAYA',
                  style: TextStyle(
                    fontFamily: 'Bebas', fontSize: 28,
                    color: AppColors.verde, letterSpacing: 4)),
                const Text('Crear cuenta nueva',
                  style: TextStyle(color: AppColors.texto2, fontSize: 13)),
              ])),
              const SizedBox(height: 24),

              // ── Error ─────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.rojo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.rojo.withOpacity(0.4))),
                  child: Text(_error!,
                    style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
                ),
              ],

              // ── Nombre ────────────────────────────────────────
              _campo('NOMBRE COMPLETO', _nombreCtrl,
                hint: 'Ej: Juan Pérez García'),

              // ── Celular ───────────────────────────────────────
              const Text('CELULAR',
                style: TextStyle(
                  fontSize: 11, color: AppColors.texto2,
                  letterSpacing: 0.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.negro3,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10)),
                    border: const Border.fromBorderSide(
                      BorderSide(color: AppColors.borde)),
                  ),
                  child: const Text('🇵🇪 +51',
                    style: TextStyle(color: AppColors.texto2, fontSize: 14)),
                ),
                Expanded(child: TextField(
                  controller: _celCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '999 888 777',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.negro3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(10)),
                      borderSide: BorderSide(color: AppColors.borde)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(10)),
                      borderSide: BorderSide(color: AppColors.borde)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(10)),
                      borderSide: BorderSide(
                        color: AppColors.verde, width: 1.5)),
                  ),
                )),
              ]),
              const SizedBox(height: 14),

              // ── DNI (opcional) ────────────────────────────────
              _campo('DNI (opcional — para facturación)', _dniCtrl,
                tipo: TextInputType.number,
                hint: 'Ej: 45678901', maxLen: 8),

              // ── Contraseña ────────────────────────────────────
              _campo('CONTRASEÑA', _passCtrl,
                obscure: true, hint: 'Mínimo 6 caracteres'),

              // ── Confirmar contraseña ──────────────────────────
              _campo('CONFIRMAR CONTRASEÑA', _pass2Ctrl,
                obscure: true, hint: 'Repite tu contraseña'),

              // ── Botón registrar ───────────────────────────────
              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: AppColors.negro,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.negro))
                  : const Text('✅  CREAR CUENTA',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('¿Ya tienes cuenta? Inicia sesión',
                  style: TextStyle(color: AppColors.texto2))),
              TextButton(
                onPressed: () => context.go('/entry'),
                child: const Text('← Volver',
                  style: TextStyle(color: AppColors.texto2))),
            ],
          ),
        ),
      ),
    );
  }
}
