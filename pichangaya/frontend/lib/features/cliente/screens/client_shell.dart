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
  bool _dropdownOpen = false;
  LocalModel? _localSeleccionado;
  // Local seleccionado desde el mapa — se pasa al tab Canchas

  void _goTab(int i) => setState(() {
    _tabIndex = i;
    _dropdownOpen = false;
  });

  void _onLocalSeleccionado(LocalModel? local) {
    // Cuando el usuario toca un local en el mapa → ir al tab Canchas
    setState(() {
      _localSeleccionado = local;
      _tabIndex = 1;
      // 1 = CanchasTab
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tabs con el local seleccionado pasado como parámetro
    final tabWidgets = [
      MapaTab(onLocalSeleccionado: _onLocalSeleccionado),
      CanchasTab(localFiltro: _localSeleccionado),
      const PagarTab(),
      const MisReservasTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _buildTopBar(),
      ),
      body: Stack(
        children: [
          IndexedStack(index: _tabIndex, children: tabWidgets),
          if (_dropdownOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() {
                  _dropdownOpen = false;
                }),
                child: Container(color: Colors.transparent),
              ),
            ),
          if (_dropdownOpen) _buildUserDropdown(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEB0A0F0D),
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '⚽ PICHANGAYA',
                style: GoogleFonts.bebasNeue(
                  fontSize: 20,
                  color: AppColors.verde,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _navBtn('📍 Cerca', 0),
                      _navBtn('Canchas', 1),
                      _navBtn('💳 Pagar', 2),
                      _navBtn('Reservas', 3),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _dropdownOpen = !_dropdownOpen;
                }),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.verde,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.verdeOsc, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        color: AppColors.negro,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(String label, int i) => GestureDetector(
    onTap: () => _goTab(i),
    child: Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _tabIndex == i ? AppColors.verdeGlow : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: _tabIndex == i ? AppColors.verde : AppColors.texto2,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _buildUserDropdown() {
    return Positioned(
      top: 56,
      right: 12,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cliente',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.verde,
              ),
            ),
            const Text(
              'PichangaYa',
              style: TextStyle(fontSize: 12, color: AppColors.texto2),
            ),
            const Divider(color: AppColors.borde, height: 20),
            _ddItem('📋 Mis Reservas', () => _goTab(3)),
            _ddItem('🚪 Cerrar sesión', () async {
              await ApiClient().logout();
              if (mounted) context.go('/entry');
            }),
          ],
        ),
      ),
    );
  }

  Widget _ddItem(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.texto2),
      ),
    ),
  );
}
