import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/providers/auth_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _State();
}

class _State extends ConsumerState<AdminLoginScreen> {
  final _celCtrl     = TextEditingController();
  final _passCtrl    = TextEditingController();
  bool  _passVisible = false;

  @override
  void dispose() {
    _celCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final celular = _celCtrl.text.trim()
        .replaceAll('+51', '').replaceAll(' ', '').replaceAll('-', '');

    if (celular.isEmpty) {
      ref.read(authProvider.notifier).setError('Ingresa tu celular');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      ref.read(authProvider.notifier).setError('Ingresa tu contraseña');
      return;
    }

    final rol = await ref
        .read(authProvider.notifier)
        .login(celular, _passCtrl.text);
    if (!mounted) return;

    if (rol == null) return; // error ya está en auth.error

    if (rol != 'admin' && rol != 'super_admin') {
      ref.read(authProvider.notifier)
          .setError('No tienes permisos de administrador');
      await ref.read(authProvider.notifier).logout();
      return;
    }

    if (rol == 'super_admin') {
      context.go('/super-admin');
    } else {
      context.go('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            color: AppColors.negro2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borde),
            boxShadow: [BoxShadow(
              color: AppColors.verde.withOpacity(0.06), blurRadius: 60)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Logo ──────────────────────────────────────
              Column(children: [
                Image.asset('assets/images/logo_pichangaya.png',
                  width: 180, fit: BoxFit.contain),
                const SizedBox(height: 6),
                const Text('PANEL ADMINISTRADOR',
                  style: TextStyle(
                    fontSize: 10, color: AppColors.texto2, letterSpacing: 5)),
              ]),
              const SizedBox(height: 28),

              // ── Error ─────────────────────────────────────
              if (auth.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.rojo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.rojo.withOpacity(0.4))),
                  child: Text(auth.error!,
                    style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
                ),
                const SizedBox(height: 14),
              ],

              // ── Celular ───────────────────────────────────
              const Text('CELULAR', style: TextStyle(
                fontSize: 11, color: AppColors.texto2,
                letterSpacing: 0.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.negro3,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8)),
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
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  decoration: const InputDecoration(
                    hintText: '911 111 111',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.negro3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(8)),
                      borderSide: BorderSide(color: AppColors.borde)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(8)),
                      borderSide: BorderSide(color: AppColors.borde)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(8)),
                      borderSide: BorderSide(
                        color: AppColors.verde, width: 1.5)),
                  ),
                )),
              ]),
              const SizedBox(height: 14),

              // ── Contraseña ────────────────────────────────
              const Text('CONTRASEÑA', style: TextStyle(
                fontSize: 11, color: AppColors.texto2,
                letterSpacing: 0.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _passCtrl,
                obscureText: !_passVisible,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  filled: true,
                  fillColor: AppColors.negro3,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.texto2, size: 20),
                    onPressed: () =>
                      setState(() => _passVisible = !_passVisible),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borde)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borde)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.verde, width: 1.5)),
                ),
              ),
              const SizedBox(height: 22),

              // ── Botón ingresar ────────────────────────────
              ElevatedButton(
                onPressed: auth.loading ? null : _login,
                style: ElevatedButton.styleFrom(
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

              TextButton(
                onPressed: () => context.go('/entry'),
                child: const Text('← Volver',
                  style: TextStyle(color: AppColors.texto2))),

              const SizedBox(height: 8),

              // ── Hints demo ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.negro3,
                  borderRadius: BorderRadius.circular(8)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡 Demo Admin:',
                      style: TextStyle(fontSize: 11, color: AppColors.texto2)),
                    SizedBox(height: 4),
                    Text.rich(TextSpan(
                      style: TextStyle(fontSize: 12, color: AppColors.texto2),
                      children: [
                        TextSpan(text: '911111111 ',
                          style: TextStyle(
                            color: AppColors.verde, fontWeight: FontWeight.w700)),
                        TextSpan(text: '/  pass: '),
                        TextSpan(text: 'admin123',
                          style: TextStyle(
                            color: AppColors.verde, fontWeight: FontWeight.w700)),
                      ],
                    )),
                    SizedBox(height: 10),
                    Text('👑 Demo Super Admin:',
                      style: TextStyle(fontSize: 11, color: AppColors.texto2)),
                    SizedBox(height: 4),
                    Text.rich(TextSpan(
                      style: TextStyle(fontSize: 12, color: AppColors.texto2),
                      children: [
                        TextSpan(text: '900000000 ',
                          style: TextStyle(
                            color: AppColors.amarillo,
                            fontWeight: FontWeight.w700)),
                        TextSpan(text: '/  pass: '),
                        TextSpan(text: 'superadmin123',
                          style: TextStyle(
                            color: AppColors.amarillo,
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
}
