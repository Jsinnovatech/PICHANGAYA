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
  State<SuperAdminShell> createState() => _State();
}

class _State extends State<SuperAdminShell> {
  int _pageIndex = 0;

  static const _navItems = [
    {'icon': '📊', 'label': 'Dashboard'},
    {'icon': '👥', 'label': 'Admins'},
    {'icon': '💳', 'label': 'Suscripciones'},
  ];

  static const _pages = [
    SuperAdminDashboardPage(),
    SuperAdminAdminsPage(),
    SuperAdminSuscripcionesPage(),
  ];

  void _goPage(int i) => setState(() {
        _pageIndex = i;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Row(children: [
        _buildSidebar(),
        Expanded(
            child: Column(children: [
          _buildTopBar(),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borde)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          )),
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
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
          color:
              active ? AppColors.amarillo.withOpacity(0.1) : Colors.transparent,
          border: Border(
              left: BorderSide(
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
    final titles = ['📊 Dashboard', '👥 Admins', '💳 Suscripciones'];
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xE60A0F0D),
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
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
          child: const Text('👑 Super Admin',
              style: TextStyle(fontSize: 12, color: AppColors.amarillo)),
        ),
      ]),
    );
  }
}
