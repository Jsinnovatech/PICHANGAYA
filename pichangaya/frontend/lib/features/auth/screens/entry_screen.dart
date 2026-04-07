import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 2),

            // ── Logo imagen ───────────────────────────────
            Image.asset(
              'assets/images/logo_pichangaya.png',
              width: 260,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            const Text(
              'Encuentra y reserva canchas sintéticas\ncerca de ti, a un solo toque',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: AppColors.texto2, height: 1.6),
            ),

            const Spacer(flex: 3),

            // ── Botones ───────────────────────────────────
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('⚡ INGRESAR',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                )),
            const SizedBox(height: 12),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/register'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('📝 CREAR CUENTA',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                )),
            const SizedBox(height: 24),

            // ── Link admin ────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('¿Eres administrador? ',
                  style: TextStyle(fontSize: 13, color: AppColors.texto2)),
              GestureDetector(
                onTap: () => context.go('/admin-login'),
                child: const Text('Panel admin',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.verde,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600)),
              ),
            ]),

            const Spacer(),
          ]),
        ),
      ),
    );
  }
}
