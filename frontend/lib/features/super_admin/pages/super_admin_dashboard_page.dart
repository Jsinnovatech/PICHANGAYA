import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});
  @override
  State<SuperAdminDashboardPage> createState() => _State();
}

class _State extends State<SuperAdminDashboardPage> {
  Map<String, dynamic>? _stats;
  List<dynamic> _ultimas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(ApiConstants.superAdminDashboard);
      setState(() {
        _stats = res.data['stats'];
        _ultimas = res.data['ultimas_suscripciones'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar dashboard';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null)
      return Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Stat cards ────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('🏟️ Complejos', '${_stats?['total_locales'] ?? 0}',
                  AppColors.verde),
              _statCard('👤 Clientes', '${_stats?['total_clientes'] ?? 0}',
                  AppColors.azul),
              _statCard(
                  '✅ Admins Activos',
                  '${_stats?['admins_con_suscripcion_activa'] ?? 0}',
                  AppColors.verde),
              _statCard(
                  '⚠️ Sin Suscripción',
                  '${_stats?['admins_sin_suscripcion'] ?? 0}',
                  AppColors.naranja),
              _statCard(
                  '⏳ Pagos Pendientes',
                  '${_stats?['suscripciones_pendientes'] ?? 0}',
                  AppColors.amarillo),
              _statCard(
                  '💰 Recaudado Mes',
                  'S/.${(_stats?['recaudado_este_mes'] ?? 0.0).toStringAsFixed(0)}',
                  AppColors.verde),
            ],
          ),

          const SizedBox(height: 24),

          // ── Total recaudado ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amarillo.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('💵', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Recaudado Histórico',
                    style: TextStyle(color: AppColors.texto2, fontSize: 12)),
                Text(
                    'S/.${(_stats?['total_recaudado'] ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.amarillo,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    )),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Mes anterior',
                    style: TextStyle(color: AppColors.texto2, fontSize: 11)),
                Text(
                    'S/.${(_stats?['recaudado_mes_anterior'] ?? 0.0).toStringAsFixed(0)}',
                    style:
                        const TextStyle(color: AppColors.texto2, fontSize: 16)),
              ]),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Últimas suscripciones ─────────────────────────
          const Text('Últimas Suscripciones Aprobadas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          const SizedBox(height: 12),

          if (_ultimas.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: const Center(
                child: Text('No hay suscripciones aprobadas aún',
                    style: TextStyle(color: AppColors.texto2)),
              ),
            )
          else
            ...(_ultimas.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.negro2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borde),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.amarillo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('💳', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['admin'] ?? '—',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )),
                        Text(
                            'Plan ${s['plan']?.toString().toUpperCase() ?? ''} · Vence: ${s['vence'] ?? '—'}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.texto2)),
                      ],
                    )),
                    Text('S/.${s['monto']?.toString() ?? '0'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amarillo,
                        )),
                  ]),
                ))).toList(),
        ]),
      ),
    );
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
            Text(
              titulo,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(valor,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
          ],
        ),
      );
}
