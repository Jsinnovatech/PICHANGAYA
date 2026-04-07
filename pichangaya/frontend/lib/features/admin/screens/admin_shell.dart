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
import 'package:pichangaya/features/admin/pages/admin_suscripcion_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int    _pageIndex   = 0;
  String _nombreAdmin = 'Admin';
  String _estadoSus   = ''; // '' | 'activo' | 'pendiente' | 'vencido'
  int    _diasSus     = 0;

  late final List<Widget> _pages;

  static const _navItems = [
    {'icon': '📊', 'label': 'Dashboard'},
    {'icon': '📋', 'label': 'Reservas'},
    {'icon': '💳', 'label': 'Pagos'},
    {'icon': '👥', 'label': 'Clientes'},
    {'icon': '⏱️', 'label': 'Timers'},
    {'icon': '🧾', 'label': 'Facturación'},
    {'icon': '🏟️', 'label': 'Canchas'},
    {'icon': '💎', 'label': 'Suscripción'},
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      const AdminDashboardPage(),
      const AdminReservasPage(),
      const AdminPagosPage(),
      const AdminClientesPage(),
      const AdminTimersPage(),
      const AdminFacturacionPage(),
      const AdminCanchasPage(),
      const AdminSuscripcionPage(),
    ];
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // Nombre del admin
    try {
      final userJson = await ApiClient().getUserJson();
      if (userJson != null && userJson.isNotEmpty) {
        final match = RegExp(r'"nombre":"([^"]*)"').firstMatch(userJson);
        final nombre = match?.group(1) ?? '';
        if (mounted && nombre.isNotEmpty) {
          setState(() => _nombreAdmin = nombre.split(' ').first);
        }
      }
    } catch (_) {}

    // Estado de suscripción
    try {
      final res = await ApiClient().dio.get('/suscripcion/mi-suscripcion');
      if (res.data != null && mounted) {
        final data = Map<String, dynamic>.from(res.data as Map);
        setState(() {
          _estadoSus = data['estado']?.toString() ?? '';
          _diasSus   = data['dias_restantes'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  void _goPage(int i) => setState(() => _pageIndex = i);

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Row(children: [
        if (isWide) _buildSidebar(),
        Expanded(child: Column(children: [
          _buildTopBar(),
          Expanded(child: IndexedStack(
              index: _pageIndex, children: _pages)),
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
      // Logo
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borde))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('⚽ PICHANGAYA',
            style: GoogleFonts.bebasNeue(
              fontSize: 20, color: AppColors.verde, letterSpacing: 2)),
          const Text('⚙️  PANEL ADMIN',
            style: TextStyle(
              fontSize: 9, color: AppColors.texto2, letterSpacing: 3)),
        ]),
      ),
      // Nav items
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _navItems.length,
        itemBuilder: (_, i) => _navItem(i),
      )),
      // Badge suscripción en sidebar
      if (_estadoSus.isNotEmpty)
        _badgeSuscripcionSidebar(),
      // Logout
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
          child: const Text('🚪  Cerrar Sesión',
            style: TextStyle(fontSize: 13)),
        ),
      ),
    ]),
  );

  Widget _navItem(int i) {
    final item   = _navItems[i];
    final active = _pageIndex == i;
    // Badge de alerta en suscripción
    final esSuscripcion = i == 7;
    final mostrarAlerta = esSuscripcion &&
        (_estadoSus == 'vencido' || _estadoSus == 'pendiente' ||
         (_estadoSus == 'activo' && _diasSus <= 7));

    return GestureDetector(
      onTap: () => _goPage(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.verdeGlow : Colors.transparent,
          border: Border(left: BorderSide(
            color: active ? AppColors.verde : Colors.transparent,
            width: 3))),
        child: Row(children: [
          Text(item['icon']!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(item['label']!,
            style: TextStyle(
              fontSize: 14,
              color: active ? AppColors.verde : AppColors.texto2,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400))),
          if (mostrarAlerta)
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _estadoSus == 'activo' && _diasSus <= 7
                    ? AppColors.amarillo
                    : AppColors.rojo,
                shape: BoxShape.circle)),
        ]),
      ),
    );
  }

  Widget _badgeSuscripcionSidebar() {
    Color color;
    String texto;
    if (_estadoSus == 'activo') {
      if (_diasSus <= 3) {
        color = AppColors.rojo;
        texto = 'Vence en $_diasSus días';
      } else if (_diasSus <= 7) {
        color = AppColors.amarillo;
        texto = '$_diasSus días restantes';
      } else {
        color = AppColors.verde;
        texto = 'Activa · $_diasSus días';
      }
    } else if (_estadoSus == 'pendiente') {
      color = AppColors.amarillo;
      texto = '⏳ Verificando pago';
    } else {
      color = AppColors.rojo;
      texto = '❌ Suscripción vencida';
    }

    return GestureDetector(
      onTap: () => _goPage(7),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4))),
        child: Row(children: [
          Icon(Icons.diamond, color: color, size: 13),
          const SizedBox(width: 6),
          Expanded(child: Text(texto,
            style: TextStyle(
              fontSize: 11, color: color,
              fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────
  Widget _buildTopBar() {
    const titles = [
      '📊 Dashboard', '📋 Reservas', '💳 Pagos',
      '👥 Clientes', '⏱️ Timers', '🧾 Facturación',
      '🏟️ Canchas', '💎 Suscripción',
    ];
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
                child: Row(children: [
                  Text(_navItems[i]['icon']!,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(_navItems[i]['label']!,
                    style: TextStyle(
                      color: _pageIndex == i
                          ? AppColors.verde : AppColors.texto,
                      fontWeight: _pageIndex == i
                          ? FontWeight.w700 : FontWeight.normal)),
                ]),
              )),
          ),
        Text(titles[_pageIndex],
          style: GoogleFonts.bebasNeue(
            fontSize: 18, color: AppColors.texto, letterSpacing: 1)),
        const Spacer(),
        // Badge suscripción en topbar (mobile)
        if (!isWide && _estadoSus.isNotEmpty &&
            (_estadoSus == 'vencido' || (_estadoSus == 'activo' && _diasSus <= 7)))
          GestureDetector(
            onTap: () => _goPage(7),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.rojo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.rojo.withOpacity(0.5))),
              child: const Text('💎 Suscripción',
                  style: TextStyle(fontSize: 11, color: AppColors.rojo)),
            ),
          ),
        // Nombre admin
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.verdeGlow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borde)),
          child: Row(children: [
            const Icon(Icons.person, color: AppColors.verde, size: 14),
            const SizedBox(width: 6),
            Text(_nombreAdmin,
              style: const TextStyle(
                fontSize: 13, color: AppColors.verde,
                fontWeight: FontWeight.w600)),
          ]),
        ),
        if (!isWide) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout,
                color: AppColors.texto2, size: 20),
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
