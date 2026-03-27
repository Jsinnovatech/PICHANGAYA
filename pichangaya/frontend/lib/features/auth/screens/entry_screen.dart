import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';

/// Equivale a screen-entry del HTML:
/// Logo + tagline + botones "Ingresar" / "Crear cuenta" + link admin
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 44),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borde),
              boxShadow: [BoxShadow(color: AppColors.verde.withOpacity(0.06), blurRadius: 60, spreadRadius: 0)],
            ),
            child: Column(
              children: [
                // Logo — .entry-logo
                Text('⚽ PICHANGAYA', style: GoogleFonts.bebasNeue(fontSize: 46, color: AppColors.verde, letterSpacing: 4)),
                const SizedBox(height: 2),
                // Sub — .entry-sub
                const Text('TU CANCHA, TU HORA', style: TextStyle(fontSize: 10, color: AppColors.texto2, letterSpacing: 5)),
                const SizedBox(height: 20),
                // Tagline — .entry-tagline
                const Text(
                  'Encuentra y reserva campos sintéticos cerca de ti, a un solo clic',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.texto2, height: 1.6),
                ),
                const SizedBox(height: 32),
                // Botón primario — Ingresar
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('👤  INGRESAR'),
                ),
                const SizedBox(height: 10),
                // Divisor — .entry-divider
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.borde)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('o', style: TextStyle(color: AppColors.texto2, fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: AppColors.borde)),
                ]),
                const SizedBox(height: 10),
                // Botón outline — Crear cuenta
                OutlinedButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('📝  CREAR CUENTA'),
                ),
                const SizedBox(height: 24),
                // Link admin — .entry-admin-link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('¿Eres administrador? ', style: TextStyle(fontSize: 13, color: AppColors.texto2)),
                  GestureDetector(
                    onTap: () => context.go('/admin-login'),
                    child: const Text('Panel admin', style: TextStyle(fontSize: 13, color: AppColors.verde, decoration: TextDecoration.underline)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
