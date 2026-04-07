import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/providers/auth_provider.dart';

class ClientLoginScreen extends ConsumerStatefulWidget {
  const ClientLoginScreen({super.key});
  @override
  ConsumerState<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends ConsumerState<ClientLoginScreen> {
  final _celularCtrl = TextEditingController();
  final _passCtrl    = TextEditingController();
  bool  _passVisible = false;

  @override
  void dispose() {
    _celularCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final celular = _celularCtrl.text.trim()
        .replaceAll('+51', '').replaceAll(' ', '').replaceAll('-', '');

    if (celular.isEmpty) {
      ref.read(authProvider.notifier).setError('Ingresa tu número de celular');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      ref.read(authProvider.notifier).setError('Ingresa tu contraseña');
      return;
    }

    final rol = await ref.read(authProvider.notifier).login(celular, _passCtrl.text);
    if (!mounted) return;

    if (rol == 'super_admin') {
      context.go('/super-admin');
    } else if (rol == 'admin') {
      context.go('/admin');
    } else if (rol == 'cliente') {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.negro,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [

            // ── Logo ──────────────────────────────────────────
            Image.asset('assets/images/logo_pichangaya.png', height: 80),
            const SizedBox(height: 8),
            const Text('PICHANGAYA',
              style: TextStyle(
                fontFamily: 'Bebas', fontSize: 32,
                color: AppColors.verde, letterSpacing: 4)),
            const SizedBox(height: 4),
            const Text('Ingresa a tu cuenta',
              style: TextStyle(color: AppColors.texto2, fontSize: 14)),
            const SizedBox(height: 32),

            // ── Error banner ──────────────────────────────────
            if (auth.error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.shade800),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(auth.error!,
                  style: const TextStyle(
                    color: Colors.redAccent, fontSize: 13)),
              ),

            // ── Campo celular ─────────────────────────────────
            TextField(
              controller: _celularCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                labelText: 'Celular',
                labelStyle: const TextStyle(color: AppColors.texto2),
                prefixIcon: const Icon(
                  Icons.phone_android, color: AppColors.texto2),
                hintText: '999 888 777',
                hintStyle: const TextStyle(
                  color: AppColors.texto2, fontSize: 13),
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
                  borderSide: const BorderSide(
                    color: AppColors.verde, width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),

            // ── Campo contraseña ──────────────────────────────
            TextField(
              controller: _passCtrl,
              obscureText: !_passVisible,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: const TextStyle(color: AppColors.texto2),
                prefixIcon: const Icon(
                  Icons.lock_outline, color: AppColors.texto2),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passVisible ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.texto2, size: 20),
                  onPressed: () =>
                    setState(() => _passVisible = !_passVisible),
                ),
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
                  borderSide: const BorderSide(
                    color: AppColors.verde, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Botón ingresar ────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: AppColors.negro,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                child: auth.loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.negro))
                  : const Text('🔐  INGRESAR',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
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

            // ── Demo hint ─────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.negro3,
                borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 Demo cliente:',
                    style: TextStyle(fontSize: 11, color: AppColors.texto2)),
                  const SizedBox(height: 4),
                  Text.rich(TextSpan(
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.texto2),
                    children: [
                      TextSpan(text: '999111222',
                        style: const TextStyle(
                          color: AppColors.verde,
                          fontWeight: FontWeight.w700)),
                      const TextSpan(text: '  /  contraseña: '),
                      TextSpan(text: 'cliente123',
                        style: const TextStyle(
                          color: AppColors.verde,
                          fontWeight: FontWeight.w700)),
                    ],
                  )),
                ],
              ),
            ),

          ]),
        ),
      ),
    );
  }
}
