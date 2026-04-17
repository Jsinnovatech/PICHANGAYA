import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'dart:convert';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});
  @override
  State<ClientLoginScreen> createState() => _State();
}

class _State extends State<ClientLoginScreen> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _verPass = false;
  String? _error;

  Future<void> _login() async {
    if (_loginCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'Ingresa tu correo o celular';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.post(ApiConstants.login, data: {
        'login': _loginCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      await ApiClient().saveTokens(
          access: res.data['access_token'], refresh: res.data['refresh_token']);
      await ApiClient().saveRol(res.data['rol']);
      await ApiClient().saveUser(jsonEncode({
        'nombre': res.data['nombre'] ?? '',
        'email': res.data['email'] ?? '',
        'celular': res.data['celular'] ?? '',
        'dni': '',
      }));
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final esRed = msg.contains('connection') || msg.contains('timeout') || msg.contains('socket');
      setState(() {
        _error = esRed ? 'Sin conexión al servidor. ¿Está el backend activo?' : 'Correo/celular o contraseña incorrectos';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.negro,
        body: Center(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borde),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ─────────────────────────────────────────────
                  Column(children: [
                    Image.asset('assets/images/logo_pichangaya.png',
                        width: 180, fit: BoxFit.contain),
                    const SizedBox(height: 8),
                    const Text('Ingresa a tu cuenta',
                        style:
                            TextStyle(color: AppColors.texto2, fontSize: 14)),
                  ]),
                  const SizedBox(height: 28),

                  // ── Error ─────────────────────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.rojo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.rojo.withOpacity(0.4)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.rojo, fontSize: 13)),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Correo o celular ──────────────────────────────────
                  const Text('CORREO O CELULAR',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.texto2,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _loginCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'ejemplo@gmail.com  ó  999888777',
                      prefixIcon: Icon(Icons.person_outline,
                          color: AppColors.texto2, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Contraseña ────────────────────────────────────────
                  const Text('CONTRASEÑA',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.texto2,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passCtrl,
                    obscureText: !_verPass,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.texto2, size: 20),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _verPass = !_verPass),
                        icon: Icon(
                          _verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.texto2,
                          size: 20,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),

                  // ── Botón ingresar ────────────────────────────────────
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
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
                        : const Text('🔐  INGRESAR',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),

                  TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('¿No tienes cuenta? Regístrate',
                          style: TextStyle(color: AppColors.texto2))),
                  TextButton(
                      onPressed: () => context.go('/entry'),
                      child: const Text('← Volver',
                          style: TextStyle(color: AppColors.texto2))),

                  // ── Hint demo ─────────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.negro3,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💡 Demo cliente:',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.texto2)),
                        SizedBox(height: 2),
                        Text.rich(TextSpan(
                          style:
                              TextStyle(fontSize: 12, color: AppColors.texto2),
                          children: [
                            TextSpan(
                                text: '999111222',
                                style: TextStyle(
                                    color: AppColors.verde,
                                    fontWeight: FontWeight.w700)),
                            TextSpan(text: '  /  '),
                            TextSpan(
                                text: 'cliente123',
                                style: TextStyle(
                                    color: AppColors.verde,
                                    fontWeight: FontWeight.w700)),
                          ],
                        )),
                      ],
                    ),
                  ),
                ]),
          ),
        )),
      );
}
