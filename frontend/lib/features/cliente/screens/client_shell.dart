import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/shared/models/local_model.dart';
import 'package:pichangaya/features/cliente/tabs/mapa_tab.dart';
import 'package:pichangaya/features/cliente/tabs/canchas_tab.dart';
import 'package:pichangaya/features/cliente/tabs/pagar_tab.dart';
import 'package:pichangaya/features/cliente/tabs/mis_reservas_tab.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});
  @override
  State<ClientShell> createState() => _State();
}

class _State extends State<ClientShell> {
  int _tabIndex = 0;
  LocalModel? _localSeleccionado;
  String _nombreCliente = '';

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  Future<void> _cargarNombre() async {
    try {
      final res = await ApiClient().dio.get('/auth/me');
      if (mounted) {
        setState(() {
          // Tomar solo el primer nombre
          final nombre = res.data['nombre'] ?? '';
          _nombreCliente = nombre.split(' ').first;
        });
      }
    } catch (_) {}
  }

  void _goTab(int i) => setState(() {
        _tabIndex = i;
      });

  void _onLocalSeleccionado(LocalModel? local) {
    setState(() {
      _localSeleccionado = local;
      _tabIndex = 1; // ir a CanchasTab
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabWidgets = [
      MapaTab(onLocalSeleccionado: _onLocalSeleccionado),
      CanchasTab(localFiltro: _localSeleccionado),
      const PagarTab(),
      const MisReservasTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.negro,
      // ── TopBar minimalista ──────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.negro2,
        elevation: 0,
        titleSpacing: 16,
        title: Text('⚽ PICHANGAYA',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              color: AppColors.verde,
              letterSpacing: 2,
            )),
        actions: [
          // Avatar con nombre
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _mostrarMenuUsuario(context),
              child: Row(children: [
                if (_nombreCliente.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('Hola, $_nombreCliente',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.texto2,
                        )),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.verde,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.verdeOsc, width: 2),
                  ),
                  child: Center(
                      child: Text(
                    _nombreCliente.isNotEmpty
                        ? _nombreCliente[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.negro,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  )),
                ),
              ]),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borde),
        ),
      ),

      // ── Contenido ───────────────────────────────────────────
      body: IndexedStack(index: _tabIndex, children: tabWidgets),

      // ── Bottom Navigation Bar — mobile-first ────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(top: BorderSide(color: AppColors.borde)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(children: [
              _navItem(0, Icons.map_outlined, Icons.map, 'Cerca'),
              _navItem(1, Icons.sports_soccer_outlined, Icons.sports_soccer,
                  'Canchas'),
              _navItem(2, Icons.payment_outlined, Icons.payment, 'Pagar'),
              _navItem(3, Icons.receipt_long_outlined, Icons.receipt_long,
                  'Reservas'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData iconOff, IconData iconOn, String label) {
    final activo = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge en Pagar si hay pagos pendientes
            Icon(
              activo ? iconOn : iconOff,
              color: activo ? AppColors.verde : AppColors.texto2,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: activo ? AppColors.verde : AppColors.texto2,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
                )),
            // Indicador activo
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: activo ? 20 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.verde,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarMenuUsuario(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borde,
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(height: 20),
            // Avatar grande
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.verde,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.verdeOsc, width: 3),
              ),
              child: Center(
                  child: Text(
                _nombreCliente.isNotEmpty
                    ? _nombreCliente[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.negro,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              )),
            ),
            const SizedBox(height: 10),
            Text(_nombreCliente.isNotEmpty ? _nombreCliente : 'Cliente',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
            const SizedBox(height: 4),
            const Text('Cliente PichangaYa',
                style: TextStyle(fontSize: 13, color: AppColors.texto2)),
            const SizedBox(height: 20),
            const Divider(color: AppColors.borde),
            const SizedBox(height: 10),
            // Mis reservas
            _menuItem(
              icon: Icons.receipt_long,
              label: 'Mis Reservas',
              onTap: () {
                Navigator.pop(context);
                _goTab(3);
              },
            ),
            const SizedBox(height: 8),
            // Cerrar sesión
            _menuItem(
              icon: Icons.logout,
              label: 'Cerrar Sesión',
              color: AppColors.rojo,
              onTap: () async {
                Navigator.pop(context);
                await ApiClient().logout();
                if (mounted) context.go('/entry');
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.texto2,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  color: color,
                  fontWeight: FontWeight.w500,
                )),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                color: color.withOpacity(0.5), size: 14),
          ]),
        ),
      );
}
