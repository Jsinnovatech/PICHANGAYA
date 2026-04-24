import 'package:pichangaya/core/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_dashboard_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_admins_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_suscripciones_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_historial_pagos_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_alertas_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_planes_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_reportes_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_locales_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_canchas_overview_page.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});
  @override
  State<SuperAdminShell> createState() => _State();
}

class _State extends State<SuperAdminShell> {
  int _pageIndex = 0;
  bool _sidebarOpen = false;
  String _nombreSuperAdmin = 'Super Admin';

  static const _navItems = [
    {'icon': '📊', 'label': 'Dashboard'},
    {'icon': '👥', 'label': 'Admins'},
    {'icon': '🏟️', 'label': 'Locales'},
    {'icon': '⚽', 'label': 'Canchas'},
    {'icon': '💳', 'label': 'Suscripciones'},
    {'icon': '📋', 'label': 'Historial Pagos'},
    {'icon': '⚠️', 'label': 'Alertas'},
    {'icon': '💎', 'label': 'Planes'},
    {'icon': '📈', 'label': 'Reportes'},
  ];

  List<Widget> get _pages => [
    const SuperAdminDashboardPage(),
    const SuperAdminAdminsPage(),
    const SuperAdminLocalesPage(),
    const SuperAdminCanchasOverviewPage(),
    const SuperAdminSuscripcionesPage(),
    const SuperAdminHistorialPagosPage(),
    const SuperAdminAlertasPage(),
    const SuperAdminPlanesPage(),
    const SuperAdminReportesPage(),
  ];

  @override
  void initState() {
    super.initState();
    _cargarNombre();
    // Registrar FCM token ahora que el JWT ya está disponible
    FcmService.instance.syncToken();
  }

  Future<void> _cargarNombre() async {
    try {
      final res = await ApiClient().dio.get('/auth/me');
      if (mounted) setState(() => _nombreSuperAdmin = res.data['nombre'] ?? 'Super Admin');
    } catch (_) {}
  }

  void _goPage(int i) => setState(() {
        _pageIndex = i;
        _sidebarOpen = false;
      });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.negro,
        body: SafeArea(
          bottom: false,
          child: Row(children: [
            _buildSidebar(),
            Expanded(child: Column(children: [
              _buildTopBar(),
              Expanded(child: _pages[_pageIndex]),
            ])),
          ]),
        ),
      );
    }

    // Mobile: overlay drawer
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            _buildTopBar(),
            Expanded(child: _pages[_pageIndex]),
          ]),
          if (_sidebarOpen) ...[
            GestureDetector(
              onTap: () => setState(() => _sidebarOpen = false),
              child: Container(
                color: Colors.black54,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: _buildSidebar(),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildSidebar() => Container(
        width: 220,
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(right: BorderSide(color: AppColors.borde)),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borde)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('⚽ PICHANGAYA',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: AppColors.amarillo,
                    letterSpacing: 2,
                  )),
              const Text('👑 SUPER ADMIN',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.amarillo,
                    letterSpacing: 3,
                  )),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _navItems.length,
              itemBuilder: (_, i) => _navItem(i),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borde)),
            ),
            child: OutlinedButton(
              onPressed: () async {
                await FcmService.instance.limpiarToken();
                await ApiClient().logout();
                if (mounted) context.go('/entry');
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
              child: const Text('🚪 Cerrar Sesión', style: TextStyle(fontSize: 13)),
            ),
          ),
        ]),
      );

  Widget _navItem(int i) {
    final item = _navItems[i];
    final active = _pageIndex == i;
    return GestureDetector(
      onTap: () => _goPage(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.amarillo.withOpacity(0.1) : Colors.transparent,
          border: Border(left: BorderSide(
            color: active ? AppColors.amarillo : Colors.transparent,
            width: 3,
          )),
        ),
        child: Row(children: [
          Text(item['icon']!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(item['label']!,
              style: TextStyle(
                fontSize: 14,
                color: active ? AppColors.amarillo : AppColors.texto2,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              )),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    final titles = ['📊 Dashboard', '👥 Admins', '🏟️ Locales', '⚽ Canchas', '💳 Suscripciones', '📋 Historial Pagos', '⚠️ Alertas', '💎 Planes', '📈 Reportes'];
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xE60A0F0D),
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        if (MediaQuery.of(context).size.width <= 900)
          IconButton(
            icon: Icon(
              _sidebarOpen ? Icons.close : Icons.menu,
              color: AppColors.texto,
            ),
            onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
          ),
        Text(titles[_pageIndex],
            style: GoogleFonts.bebasNeue(
              fontSize: 18,
              color: AppColors.texto,
              letterSpacing: 1,
            )),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.amarillo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.amarillo.withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.workspace_premium, color: AppColors.amarillo, size: 14),
            const SizedBox(width: 6),
            Text(_nombreSuperAdmin,
                style: const TextStyle(fontSize: 12, color: AppColors.amarillo, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
