import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_dashboard_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_admins_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_suscripciones_page.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});
  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _pageIndex = 0;

  static const _navItems = [
    {'icon': '📊', 'label': 'Dashboard'},
    {'icon': '👥', 'label': 'Admins'},
    {'icon': '💳', 'label': 'Suscripciones'},
  ];

  // ✅ Páginas como getter — no const estático
  List<Widget> get _pages => [
    const SuperAdminDashboardPage(),
    const SuperAdminAdminsPage(),
    const SuperAdminSuscripcionesPage(),
  ];

  void _goPage(int i) => setState(() => _pageIndex = i);

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Row(children: [
        if (isWide) _buildSidebar(),
        Expanded(child: Column(children: [
          _buildTopBar(),
          Expanded(child: IndexedStack(index: _pageIndex, children: pages)),
        ])),
      ]),
    );
  }

  // ── SIDEBAR ───────────────────────────────────────────────
  Widget _buildSidebar() => Container(
    width: 220,
    decoration: const BoxDecoration(
      color: AppColors.negro2,
      border: Border(right: BorderSide(color: AppColors.borde))),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borde))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('⚽ PICHANGAYA',
            style: GoogleFonts.bebasNeue(
              fontSize: 20, color: AppColors.amarillo, letterSpacing: 2)),
          const Text('👑 SUPER ADMIN',
            style: TextStyle(
              fontSize: 9, color: AppColors.amarillo, letterSpacing: 3)),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _navItems.length,
        itemBuilder: (_, i) => _navItem(i),
      )),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borde))),
        child: OutlinedButton(
          onPressed: () async {
            await ApiClient().logout();
            if (mounted) context.go('/entry');
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 36)),
          child: const Text('🚪 Cerrar Sesión',
            style: TextStyle(fontSize: 13)),
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
          color: active
            ? AppColors.amarillo.withOpacity(0.1) : Colors.transparent,
          border: Border(left: BorderSide(
            color: active ? AppColors.amarillo : Colors.transparent,
            width: 3)),
        ),
        child: Row(children: [
          Text(item['icon']!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(item['label']!,
            style: TextStyle(
              fontSize: 14,
              color: active ? AppColors.amarillo : AppColors.texto2,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────
  Widget _buildTopBar() {
    const titles = ['📊 Dashboard', '👥 Admins', '💳 Suscripciones'];
    final isWide = MediaQuery.of(context).size.width > 900;

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xE60A0F0D),
        border: Border(bottom: BorderSide(color: AppColors.borde))),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        // Hamburger mobile
        if (!isWide)
          PopupMenuButton<int>(
            icon: const Icon(Icons.menu, color: AppColors.texto),
            color: AppColors.negro2,
            onSelected: _goPage,
            itemBuilder: (_) => List.generate(_navItems.length, (i) =>
              PopupMenuItem(
                value: i,
                child: Text(
                  '${_navItems[i]['icon']} ${_navItems[i]['label']}',
                  style: TextStyle(
                    color: _pageIndex == i
                      ? AppColors.amarillo : AppColors.texto,
                    fontWeight: _pageIndex == i
                      ? FontWeight.w700 : FontWeight.normal)),
              )),
          ),
        Text(titles[_pageIndex],
          style: GoogleFonts.bebasNeue(
            fontSize: 18, color: AppColors.texto, letterSpacing: 1)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.amarillo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.amarillo.withOpacity(0.4))),
          child: const Text('👑 Super Admin',
            style: TextStyle(fontSize: 12, color: AppColors.amarillo)),
        ),
        if (!isWide) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.texto2, size: 20),
            onPressed: () async {
              await ApiClient().logout();
              if (mounted) context.go('/entry');
            },
          ),
        ],
      ]),
    );
  }
}
