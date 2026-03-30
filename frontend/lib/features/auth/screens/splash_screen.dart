import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

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
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final loggedIn = await ApiClient().isLoggedIn();
    if (!loggedIn) {
      context.go('/entry');
      return;
    }
    final rol = await ApiClient().getRol();
    if (rol == 'super_admin')
      context.go('/super-admin');
    else if (rol == 'admin')
      context.go('/admin');
    else
      context.go('/home');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.negro,
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo imagen
            Image.asset(
              'assets/images/logo_pichangaya.png',
              width: 280,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
                color: AppColors.verde, strokeWidth: 2),
          ],
        )),
      );
}
