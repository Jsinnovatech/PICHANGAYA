import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/features/admin/providers/dashboard_provider.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  ConsumerState<AdminDashboardPage> createState() => _State();
}

class _State extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(adminDashboardProvider.notifier).cargar());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminDashboardProvider);

    if (state.loading && state.stats == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));
    }
    if (state.error != null && state.stats == null) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(state.error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(
            onPressed: () =>
                ref.read(adminDashboardProvider.notifier).cargar(),
            child: const Text('Reintentar')),
      ]));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminDashboardProvider.notifier).cargar(),
      color: AppColors.verde,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Stat cards ──────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('📋 Reservas Hoy',
                  '${state.reservasHoy}', AppColors.verde),
              _statCard('⏳ Pendientes',
                  '${state.reservasPendientes}', AppColors.amarillo),
              _statCard('💰 Ingresos Hoy',
                  'S/.${state.ingresosHoy.toStringAsFixed(0)}', AppColors.verde),
              _statCard('👥 Clientes',
                  '${state.totalClientes}', AppColors.azul),
              _statCard('💳 Pagos Pendientes',
                  '${state.pagosPendientes}', AppColors.naranja),
              _statCard('✅ Confirmadas',
                  '${state.reservasConfirmadas}', AppColors.verde),
            ],
          ),

          const SizedBox(height: 24),

          // ── Últimas reservas ─────────────────────────────────
          Row(children: [
            const Text('Últimas Reservas',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white)),
            const Spacer(),
            GestureDetector(
              onTap: () => ref.read(adminDashboardProvider.notifier).cargar(),
              child: const Icon(Icons.refresh,
                  color: AppColors.texto2, size: 18),
            ),
          ]),
          const SizedBox(height: 12),

          if (state.ultimasReservas.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: const Center(
                child: Text('No hay reservas hoy',
                    style: TextStyle(color: AppColors.texto2)),
              ),
            )
          else
            ...state.ultimasReservas.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.negro2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borde),
                  ),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorEstado(r['estado']),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['codigo'] ?? '—',
                            style: const TextStyle(
                              fontSize: 12, color: AppColors.texto2,
                              fontWeight: FontWeight.w600)),
                        Text(r['cliente'] ?? '—',
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                        Text('${r['cancha'] ?? ''} · ${r['hora'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11, color: AppColors.texto2)),
                      ],
                    )),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('S/.${r['monto']?.toString() ?? '0'}',
                              style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: AppColors.verde)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _colorEstado(r['estado']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                                r['estado']?.toString().toUpperCase() ?? '',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _colorEstado(r['estado']),
                                  fontWeight: FontWeight.w700)),
                          ),
                        ]),
                  ]),
                )).toList(),
        ]),
      ),
    );
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'confirmed': return AppColors.verde;
      case 'pending':   return AppColors.amarillo;
      case 'active':    return AppColors.azul;
      case 'done':      return AppColors.texto2;
      case 'canceled':  return AppColors.rojo;
      default:          return AppColors.texto2;
    }
  }

  Widget _statCard(String titulo, String valor, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titulo,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(valor,
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
}
