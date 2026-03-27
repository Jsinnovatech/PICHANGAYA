import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final loggedIn = await ApiClient().isLoggedIn();
    if (!loggedIn) {
      context.go('/entry');
      return;
    }

    final rol = await ApiClient().getRol();

    // Redirigir según rol
    if (rol == 'super_admin') {
      context.go('/super-admin');
      // Super admin → su dashboard global
    } else if (rol == 'admin') {
      context.go('/admin');
      // Admin → panel de administración
    } else {
      context.go('/home');
      // Cliente → app principal con mapa y canchas
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.negro,
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('⚽ PICHANGAYA',
                style: GoogleFonts.bebasNeue(
                  fontSize: 46,
                  color: AppColors.verde,
                  letterSpacing: 4,
                )),
            const SizedBox(height: 6),
            const Text('TU CANCHA, TU HORA',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.texto2,
                  letterSpacing: 5,
                )),
            const SizedBox(height: 52),
            const CircularProgressIndicator(
                color: AppColors.verde, strokeWidth: 2),
          ],
        )),
      );
}
