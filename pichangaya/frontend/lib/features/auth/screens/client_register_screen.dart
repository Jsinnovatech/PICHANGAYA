import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

/// Equivale a screen-client-register del HTML:
/// nombre, celular, DNI opcional, pass, confirmar pass
class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});
  @override State<ClientRegisterScreen> createState() => _State();
}
class _State extends State<ClientRegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _celCtrl    = TextEditingController();
  final _dniCtrl    = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _pass2Ctrl  = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() { _error = 'Las contraseñas no coinciden'; }); return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() { _error = 'Mínimo 6 caracteres'; }); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.post(ApiConstants.register, data: {
        'nombre': _nombreCtrl.text.trim(),
        'celular': _celCtrl.text.trim(),
        'dni': _dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      await ApiClient().saveTokens(access: res.data['access_token'], refresh: res.data['refresh_token']);
      await ApiClient().saveRol(res.data['rol']);
      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      setState(() { _error = 'Error en el registro. El celular ya puede estar registrado.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? type, bool obscure = false, String? hint, int? maxLen}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.texto2, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, obscureText: obscure, keyboardType: type,
        maxLength: maxLen,
        decoration: InputDecoration(hintText: hint, counterText: ''),
      ),
      const SizedBox(height: 14),
    ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.negro,
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.negro2, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            Text('⚽ PICHANGAYA', style: GoogleFonts.bebasNeue(fontSize: 34, color: AppColors.verde, letterSpacing: 2)),
            const SizedBox(height: 4),
            const Text('Crear cuenta nueva', style: TextStyle(color: AppColors.texto2, fontSize: 14)),
          ]),
          const SizedBox(height: 28),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.rojo.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.rojo.withOpacity(0.4))),
              child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],
          _field('NOMBRE COMPLETO', _nombreCtrl, hint: 'Ej: Juan Pérez'),
          // Celular con prefijo
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
              controller: _celCtrl, keyboardType: TextInputType.phone, maxLength: 9,
              decoration: const InputDecoration(hintText: '999 888 777', counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(8)), borderSide: BorderSide(color: AppColors.borde))),
            )),
          ]),
          const SizedBox(height: 14),
          _field('DNI (opcional)', _dniCtrl, hint: '45678901', maxLen: 8),
          _field('CONTRASEÑA', _passCtrl, obscure: true, hint: 'Mínimo 6 caracteres'),
          _field('CONFIRMAR CONTRASEÑA', _pass2Ctrl, obscure: true, hint: 'Repite'),
          ElevatedButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                : const Text('✅  CREAR CUENTA'),
          ),
          TextButton(onPressed: () => context.go('/login'),
            child: const Text('¿Ya tienes cuenta? Inicia sesión', style: TextStyle(color: AppColors.texto2))),
          TextButton(onPressed: () => context.go('/entry'),
            child: const Text('← Volver', style: TextStyle(color: AppColors.texto2))),
        ]),
      ),
    )),
  );
}
