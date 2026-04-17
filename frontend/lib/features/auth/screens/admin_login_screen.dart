import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'dart:convert';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _State();
}

class _State extends State<AdminLoginScreen> {
  final _celCtrl  = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading  = false;
  bool _verPass  = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.post(ApiConstants.login, data: {
        'login':    _celCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      final rol = res.data['rol'];
      if (rol != 'admin' && rol != 'super_admin') {
        setState(() { _error = 'No tienes permisos de administrador'; });
        return;
      }
      await ApiClient().saveTokens(
        access:  res.data['access_token'],
        refresh: res.data['refresh_token'],
      );
      await ApiClient().saveRol(rol);
      await ApiClient().saveUser(jsonEncode({
        'nombre': res.data['nombre'] ?? '',
        'email': res.data['email'] ?? '',
        'celular': res.data['celular'] ?? '',
        'dni': '',
      }));
      if (!mounted) return;
      if (rol == 'super_admin') context.go('/super-admin');
      else                      context.go('/admin');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final esRed = msg.contains('connection') || msg.contains('timeout') || msg.contains('socket');
      setState(() { _error = esRed ? 'Sin conexión al servidor. ¿Está el backend activo?' : 'Celular o contraseña incorrectos'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            color: AppColors.negro2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borde),
            boxShadow: [BoxShadow(color: AppColors.verde.withOpacity(0.06), blurRadius: 60)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Logo ────────────────────────────────────────────
            Column(children: [
              Image.asset('assets/images/logo_pichangaya.png', width: 180, fit: BoxFit.contain),
              const SizedBox(height: 6),
              const Text('PANEL ADMINISTRADOR',
                  style: TextStyle(fontSize: 10, color: AppColors.texto2, letterSpacing: 5)),
            ]),
            const SizedBox(height: 28),

            // ── Error ────────────────────────────────────────────
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rojo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.rojo.withOpacity(0.4)),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
              ),
              const SizedBox(height: 14),
            ],

            // ── Celular ──────────────────────────────────────────
            const Text('CELULAR',
                style: TextStyle(fontSize: 11, color: AppColors.texto2,
                    letterSpacing: 0.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.negro3,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  border: const Border.fromBorderSide(BorderSide(color: AppColors.borde)),
                ),
                child: const Text('🇵🇪 +51', style: TextStyle(color: AppColors.texto2, fontSize: 14)),
              ),
              Expanded(child: TextField(
                controller: _celCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                decoration: const InputDecoration(
                  hintText: '911 111 111',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                    borderSide: BorderSide(color: AppColors.borde),
                  ),
                ),
              )),
            ]),
            const SizedBox(height: 14),

            // ── Contraseña ───────────────────────────────────────
            const Text('CONTRASEÑA',
                style: TextStyle(fontSize: 11, color: AppColors.texto2,
                    letterSpacing: 0.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _passCtrl,
              obscureText: !_verPass,
              decoration: InputDecoration(
                hintText: '••••••••',
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
            const SizedBox(height: 22),

            // ── Botón ingresar ───────────────────────────────────
            ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                  : const Text('🔐  INGRESAR',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),

            TextButton(
              onPressed: () => context.go('/entry'),
              child: const Text('← Volver', style: TextStyle(color: AppColors.texto2)),
            ),

            // ── Hints demo ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.negro3, borderRadius: BorderRadius.circular(8)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💡 Demo Admin:', style: TextStyle(fontSize: 11, color: AppColors.texto2)),
                SizedBox(height: 2),
                Text.rich(TextSpan(style: TextStyle(fontSize: 12, color: AppColors.texto2), children: [
                  TextSpan(text: '911111111',
                      style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w700)),
                  TextSpan(text: ' / '),
                  TextSpan(text: 'admin123',
                      style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w700)),
                ])),
                SizedBox(height: 8),
                Text('👑 Demo Super Admin:', style: TextStyle(fontSize: 11, color: AppColors.texto2)),
                SizedBox(height: 2),
                Text.rich(TextSpan(style: TextStyle(fontSize: 12, color: AppColors.texto2), children: [
                  TextSpan(text: '900000000',
                      style: TextStyle(color: AppColors.amarillo, fontWeight: FontWeight.w700)),
                  TextSpan(text: ' / '),
                  TextSpan(text: 'superadmin123',
                      style: TextStyle(color: AppColors.amarillo, fontWeight: FontWeight.w700)),
                ])),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}
