import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminAlertasPage extends StatefulWidget {
  const SuperAdminAlertasPage({super.key});
  @override
  State<SuperAdminAlertasPage> createState() => _State();
}

class _State extends State<SuperAdminAlertasPage> {
  List<dynamic> _alertas = [];
  bool _loading = true;
  String? _error;
  int _diasFiltro = 15;
  Timer? _timer;

  static const _opciones = [7, 15, 30];

  static const double _overhead   = 210.0;
  static const double _cardHeight = 100.0;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(
        ApiConstants.superAdminAlertasVenc,
        queryParameters: {'dias': _diasFiltro},
      );
      setState(() { _alertas = res.data; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error al cargar alertas'; _loading = false; });
    }
  }

  void _setDias(int d) {
    if (_diasFiltro == d) return;
    setState(() { _diasFiltro = d; _page = 0; });
    _cargar();
  }

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

  Color _colorDias(int dias) {
    if (dias <= 3)  return AppColors.rojo;
    if (dias <= 7)  return AppColors.naranja;
    if (dias <= 15) return AppColors.amarillo;
    return AppColors.verde;
  }

  String _labelUrgencia(int dias) {
    if (dias <= 3)  return 'CRÍTICO';
    if (dias <= 7)  return 'URGENTE';
    if (dias <= 15) return 'PRÓXIMO';
    return 'PENDIENTE';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    final ps    = _pageSize(context);
    final total = (_alertas.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _alertas.skip(page * ps).take(ps).toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Selector de días ──────────────────────────
          Row(children: [
            const Text('Vencen en: ', style: TextStyle(color: AppColors.texto2, fontSize: 13)),
            const SizedBox(width: 8),
            ..._opciones.map((d) {
              final active = _diasFiltro == d;
              return GestureDetector(
                onTap: () => _setDias(d),
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
                  child: Text(
                    '$d días',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? AppColors.amarillo : AppColors.texto2,
                    ),
                  ),
                ),
              );
            }),
          ]),
          const SizedBox(height: 8),

          // ── Resumen ───────────────────────────────────
          if (_alertas.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.amarillo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amarillo.withOpacity(0.3)),
              ),
              child: Text(
                '⚠️  ${_alertas.length} admin${_alertas.length > 1 ? 's' : ''} vence${_alertas.length == 1 ? '' : 'n'} en los próximos $_diasFiltro días',
                style: const TextStyle(color: AppColors.amarillo, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),

          // ── Lista ──────────────────────────────────
          if (_alertas.isEmpty)
            const Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('✅', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('Sin alertas en este período',
                      style: TextStyle(color: AppColors.texto2, fontSize: 15)),
                ]),
              ),
            )
          else ...[
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (_, i) => _buildCard(items[i]),
              ),
            ),
            if (total > 1) _paginacion(total, page),
          ],
        ]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> a) {
    final dias  = (a['dias_restantes'] as num?)?.toInt() ?? 0;
    final color = _colorDias(dias);
    final label = _labelUrgencia(dias);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(children: [
        // Días restantes — visual destacado
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$dias', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text('días', style: TextStyle(fontSize: 9, color: color)),
          ]),
        ),
        const SizedBox(width: 12),
        // Info admin
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['admin_nombre'] ?? '—',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                overflow: TextOverflow.ellipsis),
            Text('+51 ${a['admin_celular'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
            Text(
              'Plan ${(a['plan'] as String?)?.toUpperCase() ?? ''} · S/.${(a['monto'] as num?)?.toStringAsFixed(0) ?? '0'}/mes',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2),
            ),
          ]),
        ),
        // Badge urgencia + fecha
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(height: 4),
          Text(
            'Vence: ${a['fecha_vencimiento'] ?? '—'}',
            style: const TextStyle(fontSize: 11, color: AppColors.texto2),
          ),
        ]),
      ]),
    );
  }

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _arrowBtn(Icons.arrow_back_ios_new, current > 0,
            () => setState(() => _page = current - 1)),
        ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
        if (total > 9)
          Text('${current + 1} / $total',
              style: const TextStyle(color: AppColors.amarillo, fontSize: 14, fontWeight: FontWeight.w700)),
        _arrowBtn(Icons.arrow_forward_ios, current < total - 1,
            () => setState(() => _page = current + 1)),
      ],
    ),
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => IconButton(
    icon: Icon(icon, size: 16, color: enabled ? AppColors.amarillo : AppColors.borde),
    onPressed: enabled ? onTap : null,
  );

  Widget _pageNum(int i, int current) {
    final active = i == current;
    return GestureDetector(
      onTap: () => setState(() => _page = i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: active ? AppColors.amarillo.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? AppColors.amarillo : AppColors.borde),
        ),
        child: Center(child: Text('${i + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.amarillo : AppColors.texto2,
            ))),
      ),
    );
  }
}
