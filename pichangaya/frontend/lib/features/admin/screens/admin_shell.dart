import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/features/admin/pages/admin_dashboard_page.dart';
import 'package:pichangaya/features/admin/pages/admin_reservas_page.dart';
import 'package:pichangaya/features/admin/pages/admin_pagos_page.dart';
import 'package:pichangaya/features/admin/pages/admin_clientes_page.dart';
import 'package:pichangaya/features/admin/pages/admin_timers_page.dart';
import 'package:pichangaya/features/admin/pages/admin_facturacion_page.dart';
import 'package:pichangaya/features/admin/pages/admin_canchas_page.dart';

/// Equivale a screen-admin del HTML.
/// Sidebar con 7 items + área de contenido (admin-content).
/// En mobile: sidebar oculto, toggle hamburger en topbar.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override State<AdminShell> createState() => _State();
}

class _State extends State<AdminShell> {
  int _pageIndex = 0;
  bool _sidebarOpen = false; // para mobile

  // Orden igual al HTML
  static const _navItems = [
    {'icon': '📊', 'label': 'Dashboard'},
    {'icon': '📋', 'label': 'Reservas'},
    {'icon': '💳', 'label': 'Pagos'},
    {'icon': '👥', 'label': 'Clientes'},
    {'icon': '⏱️', 'label': 'Timers'},
    {'icon': '🧾', 'label': 'Facturación'},
    {'icon': '🏟️', 'label': 'Canchas'},
  ];

  static const _pages = [
    AdminDashboardPage(),
    AdminReservasPage(),
    AdminPagosPage(),
    AdminClientesPage(),
    AdminTimersPage(),
    AdminFacturacionPage(),
    AdminCanchasPage(),
  ];

  void _goPage(int i) => setState(() { _pageIndex = i; _sidebarOpen = false; });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Row(children: [
        // SIDEBAR — visible siempre en wide, overlay en mobile
        if (isWide) _buildSidebar(),
        if (!isWide && _sidebarOpen) ...[
          // overlay
          GestureDetector(
            onTap: () => setState(() { _sidebarOpen = false; }),
            child: Container(color: Colors.black.withOpacity(0.6), width: MediaQuery.of(context).size.width),
          ),
        ],
        // Contenido principal
        Expanded(child: Column(children: [
          _buildAdminTopBar(),
          Expanded(child: _pages[_pageIndex]),
        ])),
      ]),
    );
  }

  Widget _buildSidebar() => Container(
    width: 220,
    decoration: const BoxDecoration(
      color: AppColors.negro2,
      border: Border(right: BorderSide(color: AppColors.borde)),
    ),
    child: Column(children: [
      // .sidebar-logo
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borde))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('⚽ PICHANGAYA', style: GoogleFonts.bebasNeue(fontSize: 20, color: AppColors.verde, letterSpacing: 2)),
          const Text('⚙️  PANEL ADMIN', style: TextStyle(fontSize: 9, color: AppColors.texto2, letterSpacing: 3)),
        ]),
      ),
      // .sidebar-nav
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _navItems.length,
        itemBuilder: (_, i) => _navItem(i),
      )),
      // .sidebar-footer
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borde))),
        child: OutlinedButton(
          onPressed: () async {
            await ApiClient().logout();
            if (mounted) context.go('/entry');
          },
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
          child: const Text('🚪  Cerrar Sesión', style: TextStyle(fontSize: 13)),
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
          color: active ? AppColors.verdeGlow : Colors.transparent,
          border: Border(left: BorderSide(color: active ? AppColors.verde : Colors.transparent, width: 3)),
        ),
        child: Row(children: [
          Text(item['icon']!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(item['label']!, style: TextStyle(
            fontSize: 14, color: active ? AppColors.verde : AppColors.texto2, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }

  Widget _buildAdminTopBar() {
    final titles = ['📊 Dashboard','📋 Reservas','💳 Pagos','👥 Clientes','⏱️ Timers','🧾 Facturación','🏟️ Canchas'];
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xE60A0F0D),
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        // Hamburger en mobile
        if (MediaQuery.of(context).size.width <= 900)
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.texto),
            onPressed: () => setState(() { _sidebarOpen = !_sidebarOpen; }),
          ),
        Text(titles[_pageIndex], style: GoogleFonts.bebasNeue(fontSize: 18, color: AppColors.texto, letterSpacing: 1)),
        const Spacer(),
        const Text('Admin', style: TextStyle(fontSize: 12, color: AppColors.texto2)),
        const SizedBox(width: 8),
        // Botón "Ver cliente" como en el HTML
        OutlinedButton(
          onPressed: () => context.go('/home'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('👁️ Ver cliente'),
        ),
      ]),
    );
  }
}
