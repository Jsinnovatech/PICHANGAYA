import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/features/admin/pages/admin_dashboard_page.dart';
import 'package:pichangaya/features/admin/pages/admin_ultimas_reservas_page.dart';
import 'package:pichangaya/features/admin/pages/admin_reservas_page.dart';
import 'package:pichangaya/features/admin/pages/admin_pagos_page.dart';
import 'package:pichangaya/features/admin/pages/admin_clientes_page.dart';
import 'package:pichangaya/features/admin/pages/admin_timers_page.dart';
import 'package:pichangaya/features/admin/pages/admin_facturacion_page.dart';
import 'package:pichangaya/features/admin/pages/admin_canchas_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _State();
}

class _State extends State<AdminShell> {
  int _pageIndex = 0;
  bool _sidebarOpen = false;
  String _nombreAdmin = 'Admin';

  static const _navItems = [
    {'icon': '📊', 'label': 'Dashboard'},
    {'icon': '🕐', 'label': 'Últimas Reservas'},
    {'icon': '📋', 'label': 'Reservas'},
    {'icon': '💳', 'label': 'Pagos'},
    {'icon': '👥', 'label': 'Clientes'},
    {'icon': '⏱️', 'label': 'Timers'},
    {'icon': '🧾', 'label': 'Facturación'},
    {'icon': '🏟️', 'label': 'Canchas'},
  ];

  static const _pages = [
    AdminDashboardPage(),
    AdminUltimasReservasPage(),
    AdminReservasPage(),
    AdminPagosPage(),
    AdminClientesPage(),
    AdminTimersPage(),
    AdminFacturacionPage(),
    AdminCanchasPage(),
  ];

  @override
  void initState() {
    super.initState();
    _cargarNombreAdmin();
  }

  Future<void> _cargarNombreAdmin() async {
    try {
      final res = await ApiClient().dio.get('/auth/me');
      if (mounted) setState(() => _nombreAdmin = res.data['nombre'] ?? 'Admin');
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
        body: Row(children: [
          _buildSidebar(),
          Expanded(child: Column(children: [
            _buildTopBar(),
            Expanded(child: _pages[_pageIndex]),
          ])),
        ]),
      );
    }

    // Mobile: overlay drawer
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Stack(children: [
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
                  style: GoogleFonts.bebasNeue(fontSize: 20, color: AppColors.verde, letterSpacing: 2)),
              const Text('⚙️  PANEL ADMIN',
                  style: TextStyle(fontSize: 9, color: AppColors.texto2, letterSpacing: 3)),
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
          border: Border(left: BorderSide(
            color: active ? AppColors.verde : Colors.transparent,
            width: 3,
          )),
        ),
        child: Row(children: [
          Text(item['icon']!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(item['label']!,
              style: TextStyle(
                fontSize: 14,
                color: active ? AppColors.verde : AppColors.texto2,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              )),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    final titles = [
      '📊 Dashboard',
      '🕐 Últimas Reservas',
      '📋 Reservas',
      '💳 Pagos',
      '👥 Clientes',
      '⏱️ Timers',
      '🧾 Facturación',
      '🏟️ Canchas',
    ];
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
            style: GoogleFonts.bebasNeue(fontSize: 18, color: AppColors.texto, letterSpacing: 1)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.verdeGlow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borde),
          ),
          child: Row(children: [
            const Icon(Icons.person, color: AppColors.verde, size: 14),
            const SizedBox(width: 6),
            Text(_nombreAdmin,
                style: const TextStyle(fontSize: 13, color: AppColors.verde, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
