import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  List<dynamic> _pagosMetodo = [];
  List<dynamic> _reservasMes = [];
  bool _loading = true;
  String? _error;
  int _pieTouched = -1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminDashboard);
      setState(() {
        _stats = res.data['stats'];
        _pagosMetodo = res.data['pagos_por_metodo'] ?? [];
        _reservasMes = res.data['reservas_por_mes'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'Error al cargar dashboard'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ],
    ));

    final confirmadas = (_stats?['reservas_hoy'] ?? 0) - (_stats?['reservas_pendientes'] ?? 0);

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Stat cards ────────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              _statCard('📋 Reservas Hoy',   '${_stats?['reservas_hoy'] ?? 0}',        AppColors.verde),
              _statCard('⏳ Pendientes',      '${_stats?['reservas_pendientes'] ?? 0}', AppColors.amarillo),
              _statCard('💰 Ingresos Hoy',   'S/.${(_stats?['ingresos_hoy'] ?? 0.0).toStringAsFixed(0)}', AppColors.verde),
              _statCard('💵 Ingresos Mes',   'S/.${(_stats?['ingresos_mes'] ?? 0.0).toStringAsFixed(0)}', AppColors.azul),
              _statCard('👥 Clientes',        '${_stats?['total_clientes'] ?? 0}',      AppColors.azul),
              _statCard('📦 Total Reservas', '${_stats?['total_reservas'] ?? 0}',       AppColors.texto2),
              _statCard('💳 Pagos Pend.',    '${_stats?['pagos_pendientes'] ?? 0}',     AppColors.naranja),
              _statCard('✅ Confirmadas Hoy','$confirmadas',                            AppColors.verde),
            ],
          ),

          const SizedBox(height: 24),

          // ── Pie chart: pagos por método ────────────────────────
          _sectionTitle('💳 Pagos por Método'),
          const SizedBox(height: 12),
          _pagosMetodo.isEmpty
              ? _emptyBox('Sin pagos verificados aún')
              : _buildPieChart(),

          const SizedBox(height: 24),

          // ── Barras: reservas por mes ───────────────────────────
          _sectionTitle('📅 Reservas por Mes (últimos 6 meses)'),
          const SizedBox(height: 12),
          _reservasMes.isEmpty
              ? _emptyBox('Sin datos de reservas')
              : _buildBarChart(),

          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── Pie chart ────────────────────────────────────────────────────
  Widget _buildPieChart() {
    final colores = [
      AppColors.verde,
      AppColors.azul,
      AppColors.amarillo,
      AppColors.naranja,
      AppColors.rojo,
    ];
    final total = _pagosMetodo.fold<double>(0, (s, e) => s + (e['cantidad'] as int));

    final sections = List.generate(_pagosMetodo.length, (i) {
      final item = _pagosMetodo[i];
      final pct = total > 0 ? (item['cantidad'] as int) / total * 100 : 0.0;
      final isTouched = i == _pieTouched;
      return PieChartSectionData(
        color: colores[i % colores.length],
        value: (item['cantidad'] as int).toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        radius: isTouched ? 70 : 58,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
      );
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(children: [
        SizedBox(
          height: 200,
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  _pieTouched = response?.touchedSection?.touchedSectionIndex ?? -1;
                });
              },
            ),
            sections: sections,
            centerSpaceRadius: 40,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(height: 16),
        // Leyenda
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(_pagosMetodo.length, (i) {
            final item = _pagosMetodo[i];
            final color = colores[i % colores.length];
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${_labelMetodo(item['metodo'])} (${item['cantidad']})',
                  style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
            ]);
          }),
        ),
        const SizedBox(height: 12),
        // Totales por método
        ...List.generate(_pagosMetodo.length, (i) {
          final item = _pagosMetodo[i];
          final color = colores[i % colores.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(_labelMetodo(item['metodo']),
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('S/.${(item['total'] as double).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Bar chart reservas por mes ───────────────────────────────────
  Widget _buildBarChart() {
    final maxVal = _reservasMes.fold<double>(0, (m, e) => m > (e['cantidad'] as int).toDouble() ? m : (e['cantidad'] as int).toDouble());
    final yMax = (maxVal < 5 ? 5 : maxVal + 2).toDouble();

    final bars = List.generate(_reservasMes.length, (i) {
      final item = _reservasMes[i];
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: (item['cantidad'] as int).toDouble(),
          color: AppColors.verde,
          width: 22,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ]);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          maxY: yMax,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.borde, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: const TextStyle(fontSize: 10, color: AppColors.texto2)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= _reservasMes.length) return const SizedBox();
                return Text(_reservasMes[i]['mes'] ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.texto2));
              },
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${rod.toY.toInt()} reservas',
                const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        )),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white));

  Widget _emptyBox(String msg) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.negro2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borde)),
    child: Center(child: Text(msg, style: const TextStyle(color: AppColors.texto2))),
  );

  String _labelMetodo(String? m) {
    switch (m) {
      case 'yape':           return 'Yape';
      case 'plin':           return 'Plin';
      case 'transferencia':  return 'Transferencia';
      case 'efectivo':       return 'Efectivo';
      case 'tarjeta':        return 'Tarjeta';
      default:               return m ?? '—';
    }
  }

  Widget _statCard(String titulo, String valor, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.negro2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titulo, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
      ],
    ),
  );
}
