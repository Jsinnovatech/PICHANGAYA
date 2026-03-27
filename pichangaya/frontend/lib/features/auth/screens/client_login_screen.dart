import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

/// Equivale a screen-client-login del HTML:
/// Celular (+51), contraseña, hint demo, link registro, volver
class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});
  @override State<ClientLoginScreen> createState() => _State();
}
class _State extends State<ClientLoginScreen> {
  final _celCtrl  = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.post(ApiConstants.login, data: {
        'celular': _celCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      await ApiClient().saveTokens(access: res.data['access_token'], refresh: res.data['refresh_token']);
      await ApiClient().saveRol(res.data['rol']);
      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      setState(() { _error = 'Celular o contraseña incorrectos'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.negro,
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header — .auth-header
          Column(children: [
            Text('⚽ PICHANGAYA', style: GoogleFonts.bebasNeue(fontSize: 34, color: AppColors.verde, letterSpacing: 2)),
            const SizedBox(height: 4),
            const Text('Ingresa a tu cuenta', style: TextStyle(color: AppColors.texto2, fontSize: 14)),
          ]),
          const SizedBox(height: 28),
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
          // Campo celular con prefijo +51 — .phone-prefix del HTML
          const Text('CELULAR', style: TextStyle(fontSize: 11, color: AppColors.texto2, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
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
                hintText: '999 888 777',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                  borderSide: BorderSide(color: AppColors.borde),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 14),
          const Text('CONTRASEÑA', style: TextStyle(fontSize: 11, color: AppColors.texto2, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(hintText: '••••••••'),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                : const Text('🔐  INGRESAR'),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: () => context.go('/register'),
            child: const Text('¿No tienes cuenta? Regístrate', style: TextStyle(color: AppColors.texto2))),
          TextButton(onPressed: () => context.go('/entry'),
            child: const Text('← Volver', style: TextStyle(color: AppColors.texto2))),
          // Hint demo — .auth-demo-hint
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.negro3, borderRadius: BorderRadius.circular(8)),
            child: const Text.rich(TextSpan(
              style: TextStyle(fontSize: 12, color: AppColors.texto2),
              children: [
                TextSpan(text: '💡 Demo: '),
                TextSpan(text: '999111222', style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w700)),
                TextSpan(text: ' / '),
                TextSpan(text: 'cliente123', style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w700)),
              ],
            )),
          ),
        ]),
      ),
    )),
  );
}
