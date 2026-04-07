import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    await ref.read(authProvider.notifier).init();
    if (!mounted) return;

    final rol = ref.read(authProvider).rol;
    if (rol == 'super_admin') {
      context.go('/super-admin');
    } else if (rol == 'admin') {
      context.go('/admin');
    } else if (rol == 'cliente') {
      context.go('/home');
    } else {
      context.go('/entry');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.negro,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_pichangaya.png',
                width: 280,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                  color: AppColors.verde, strokeWidth: 2),
            ],
          ),
        ),
      );
}
