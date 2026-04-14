import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminUltimasReservasPage extends StatefulWidget {
  const AdminUltimasReservasPage({super.key});
  @override
  State<AdminUltimasReservasPage> createState() => _State();
}

class _State extends State<AdminUltimasReservasPage> {
  List<dynamic> _reservas = [];
  bool _loading = true;
  String? _error;
  int _page = 0;

  // Overhead: appbar(56) + tabbar(48) + header(40) + toppad(12) + pagination(50) + margins(24)
  static const double _overhead    = 230.0;
  static const double _cardHeight  = 90.0;  // card padding + content + margin

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(2, 20);
  }

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminDashboard);
      setState(() { _reservas = res.data['ultimas_reservas'] ?? []; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Error al cargar reservas'; _loading = false; });
    }
  }

  Color _colorEstado(String? e) {
    switch (e) {
      case 'confirmed': return AppColors.verde;
      case 'pending':   return AppColors.amarillo;
      case 'active':    return AppColors.azul;
      case 'done':      return AppColors.texto2;
      case 'canceled':  return AppColors.rojo;
      default:          return AppColors.texto2;
    }
  }

  String _labelEstado(String? e) {
    switch (e) {
      case 'confirmed': return 'CONFIRMADA';
      case 'pending':   return 'PENDIENTE';
      case 'active':    return 'EN JUEGO';
      case 'done':      return 'FINALIZADA';
      case 'canceled':  return 'CANCELADA';
      default:          return e?.toUpperCase() ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_error!, style: const TextStyle(color: AppColors.rojo)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
    ]));

    final ps    = _pageSize(context);
    final total = (_reservas.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _reservas.skip(page * ps).take(ps).toList();

    return Column(children: [
      // ── Header ───────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          const Text('Últimas Reservas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          Text('${_reservas.length} registros',
              style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          const SizedBox(width: 8),
          GestureDetector(onTap: _cargar,
              child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
        ]),
      ),

      // ── Cards de la página actual ─────────────────────────────
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          color: AppColors.verde,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            itemCount: items.length,
            itemBuilder: (_, i) => _cardReserva(items[i]),
          ),
        ),
      ),

      // ── Paginación ────────────────────────────────────────────
      if (total > 1) ...[
        _paginacion(total, page),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Widget _cardReserva(dynamic r) {
    final color = _colorEstado(r['estado']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(r['codigo'] ?? '—',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(_labelEstado(r['estado']),
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(r['cliente'] ?? '—',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('${r['cancha'] ?? ''} · ${r['fecha'] ?? ''} · ${r['hora'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
        ])),
        Text('S/.${r['monto']?.toString() ?? '0'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.verde)),
      ]),
    );
  }

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0,
          () => setState(() => _page = current - 1)),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current, total)),
      if (total > 9) Text('${current + 1} / $total',
          style: const TextStyle(color: AppColors.verde, fontSize: 14, fontWeight: FontWeight.w700)),
      _arrowBtn(Icons.arrow_forward_ios, current < total - 1,
          () => setState(() => _page = current + 1)),
    ]),
  );

  Widget _pageNum(int i, int current, int total) => GestureDetector(
    onTap: () => setState(() => _page = i),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: i == current ? AppColors.verde.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: i == current ? AppColors.verde : Colors.transparent),
      ),
      child: Text('${i + 1}', style: TextStyle(
        fontSize: 13,
        fontWeight: i == current ? FontWeight.w700 : FontWeight.normal,
        color: i == current ? AppColors.verde : AppColors.texto2,
      )),
    ),
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Icon(icon, size: 16, color: enabled ? AppColors.verde : AppColors.borde),
    ),
  );
}
