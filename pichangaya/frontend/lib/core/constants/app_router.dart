import 'package:go_router/go_router.dart';
import 'package:pichangaya/features/auth/screens/entry_screen.dart';
import 'package:pichangaya/features/auth/screens/client_login_screen.dart';
import 'package:pichangaya/features/auth/screens/client_register_screen.dart';
import 'package:pichangaya/features/auth/screens/admin_login_screen.dart';
import 'package:pichangaya/features/auth/screens/splash_screen.dart';
import 'package:pichangaya/features/cliente/screens/client_shell.dart';
import 'package:pichangaya/features/admin/screens/admin_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      GoRoute(path: '/entry', builder: (_, __) => const EntryScreen()),

      GoRoute(path: '/login', builder: (_, __) => const ClientLoginScreen()),

      GoRoute(
          path: '/register', builder: (_, __) => const ClientRegisterScreen()),

      GoRoute(
          path: '/admin-login', builder: (_, __) => const AdminLoginScreen()),

      GoRoute(path: '/home', builder: (_, __) => const ClientShell()),

      GoRoute(path: '/admin', builder: (_, __) => const AdminShell()),

      // Super admin usa el mismo AdminShell por ahora
      // En Fase 3 crearemos un SuperAdminShell separado
      GoRoute(path: '/super-admin', builder: (_, __) => const AdminShell()),
    ],
  );
}
