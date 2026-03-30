import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _State();
}

class _State extends State<AdminDashboardPage> {
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
      final res = await ApiClient().dio.get(ApiConstants.adminDashboard);
      setState(() {
        _stats = res.data['stats'];
        _ultimas = res.data['ultimas_reservas'] ?? [];
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
          child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null)
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]));

    return RefreshIndicator(
      onRefresh: _cargar,
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
              _statCard('📋 Reservas Hoy', '${_stats?['reservas_hoy'] ?? 0}',
                  AppColors.verde),
              _statCard('⏳ Pendientes',
                  '${_stats?['reservas_pendientes'] ?? 0}', AppColors.amarillo),
              _statCard(
                  '💰 Ingresos Hoy',
                  'S/.${(_stats?['ingresos_hoy'] ?? 0.0).toStringAsFixed(0)}',
                  AppColors.verde),
              _statCard('👥 Clientes', '${_stats?['total_clientes'] ?? 0}',
                  AppColors.azul),
              _statCard('💳 Pagos Pendientes',
                  '${_stats?['pagos_pendientes'] ?? 0}', AppColors.naranja),
              _statCard(
                  '✅ Confirmadas',
                  '${(_stats?['reservas_hoy'] ?? 0) - (_stats?['reservas_pendientes'] ?? 0)}',
                  AppColors.verde),
            ],
          ),

          const SizedBox(height: 24),

          // ── Últimas reservas ─────────────────────────────────
          Row(children: [
            const Text('Últimas Reservas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
            const Spacer(),
            GestureDetector(
              onTap: _cargar,
              child:
                  const Icon(Icons.refresh, color: AppColors.texto2, size: 18),
            ),
          ]),
          const SizedBox(height: 12),

          if (_ultimas.isEmpty)
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
            ...(_ultimas.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.negro2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borde),
                  ),
                  child: Row(children: [
                    // Estado badge
                    Container(
                      width: 8,
                      height: 8,
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
                              fontSize: 12,
                              color: AppColors.texto2,
                              fontWeight: FontWeight.w600,
                            )),
                        Text(r['cliente'] ?? '—',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                        Text('${r['cancha'] ?? ''} · ${r['hora'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.texto2,
                            )),
                      ],
                    )),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('S/.${r['monto']?.toString() ?? '0'}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.verde,
                              )),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _colorEstado(r['estado']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                                r['estado']?.toString().toUpperCase() ?? '',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _colorEstado(r['estado']),
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ]),
                  ]),
                ))).toList(),
        ]),
      ),
    );
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'confirmed':
        return AppColors.verde;
      case 'pending':
        return AppColors.amarillo;
      case 'active':
        return AppColors.azul;
      case 'done':
        return AppColors.texto2;
      case 'canceled':
        return AppColors.rojo;
      default:
        return AppColors.texto2;
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
