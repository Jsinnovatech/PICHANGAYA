import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminReportesPage extends StatefulWidget {
  const SuperAdminReportesPage({super.key});
  @override
  State<SuperAdminReportesPage> createState() => _State();
}

class _State extends State<SuperAdminReportesPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _meses = 6;

  static const _mesesOpciones = [3, 6, 12];
  static const _mesesNombres  = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(
        ApiConstants.superAdminReportes,
        queryParameters: {'meses': _meses},
      );
      setState(() { _data = res.data; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error al cargar reportes'; _loading = false; });
    }
  }

  void _setMeses(int m) {
    if (_meses == m) return;
    setState(() => _meses = m);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    final ingresos  = (_data!['ingresos_por_mes'] as List).cast<Map<String, dynamic>>();
    final porPlan   = (_data!['por_plan'] as List).cast<Map<String, dynamic>>();
    final topAdmins = (_data!['top_admins'] as List).cast<Map<String, dynamic>>();

    final totalPeriodo = ingresos.fold<double>(0, (s, e) => s + (e['total'] as num).toDouble());
    final maxValor = ingresos.isEmpty ? 1.0
        : ingresos.map((e) => (e['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Período: ', style: TextStyle(color: AppColors.texto2, fontSize: 13)),
            const SizedBox(width: 8),
            ..._mesesOpciones.map((m) {
              final active = _meses == m;
              return GestureDetector(
                onTap: () => _setMeses(m),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? AppColors.amarillo.withOpacity(0.15) : AppColors.negro2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? AppColors.amarillo : AppColors.borde,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text('$m meses',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? AppColors.amarillo : AppColors.texto2,
                    )),
                ),
              );
            }),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amarillo.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('💵', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total recaudado en el período',
                    style: TextStyle(color: AppColors.texto2, fontSize: 12)),
                Text('S/.${totalPeriodo.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.amarillo,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    )),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('📊 Ingresos por mes',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borde),
            ),
            child: ingresos.every((e) => (e['total'] as num) == 0)
                ? const Center(
                    child: Text('Sin datos en este período',
                        style: TextStyle(color: AppColors.texto2)))
                : BarChart(
                    BarChartData(
                      maxY: maxValor * 1.25,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.borde.withOpacity(0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (val, _) => Text(
                              'S/.${val.toInt()}',
                              style: const TextStyle(color: AppColors.texto2, fontSize: 9),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= ingresos.length) return const SizedBox();
                              final mes = (ingresos[idx]['mes'] as num).toInt();
                              return Text(
                                _mesesNombres[mes - 1],
                                style: const TextStyle(color: AppColors.texto2, fontSize: 10),
                              );
                            },
                          ),
                        ),
                        rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: List.generate(ingresos.length, (i) {
                        final val = (ingresos[i]['total'] as num).toDouble();
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              color: AppColors.amarillo,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxValor * 1.25,
                                color: AppColors.amarillo.withOpacity(0.05),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          const Text('💳 Distribución por plan',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (porPlan.isEmpty)
            _sinDatos()
          else
            ...porPlan.map((p) {
              final color    = _colorPlan(p['plan'] as String? ?? '');
              final total    = (p['total'] as num).toDouble();
              final cantidad = (p['cantidad'] as num).toInt();
              final pct      = totalPeriodo > 0 ? (total / totalPeriodo * 100) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.negro2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text((p['plan'] as String).toUpperCase(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                    const Spacer(),
                    Text('$cantidad pago${cantidad != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
                    const SizedBox(width: 10),
                    Text('S/.${total.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 5,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 10, color: AppColors.texto2)),
                  ),
                ]),
              );
            }),
          const SizedBox(height: 20),
          const Text('🏆 Top admins por pago',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (topAdmins.isEmpty)
            _sinDatos()
          else
            ...List.generate(topAdmins.length, (i) {
              final a       = topAdmins[i];
              final medallas = ['🥇','🥈','🥉','4️⃣','5️⃣'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.negro2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borde),
                ),
                child: Row(children: [
                  Text(medallas[i], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(a['nombre'] ?? '—',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  Text('S/.${(a['total'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.verde)),
                ]),
              );
            }),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sinDatos() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.negro2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borde),
    ),
    child: const Center(
      child: Text('Sin datos', style: TextStyle(color: AppColors.texto2)),
    ),
  );

  Color _colorPlan(String p) {
    switch (p) {
      case 'free':     return AppColors.texto2;
      case 'boleta':   return AppColors.azul;
      case 'factura':  return AppColors.verde;
      case 'completo': return AppColors.amarillo;
      default:         return AppColors.naranja;
    }
  }
}
