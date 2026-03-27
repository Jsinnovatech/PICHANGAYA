import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
// initializeDateFormatting necesario para fechas en español
import 'package:pichangaya/core/theme/app_theme.dart';
import 'package:pichangaya/core/constants/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  // Inicializa el locale español para DateFormat('d MMM', 'es')
  // Sin esto lanza LocaleDataException al formatear fechas
  runApp(const ProviderScope(child: PichangaYaApp()));
}

class PichangaYaApp extends ConsumerWidget {
  const PichangaYaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PichangaYa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}
