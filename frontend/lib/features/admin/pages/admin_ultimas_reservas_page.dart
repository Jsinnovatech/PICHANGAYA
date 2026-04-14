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
  int _carouselPage = 0;
  final _pageCtrl = PageController(viewportFraction: 0.88);

  static const int _verticalCount = 7;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminDashboard);
      setState(() {
        _reservas = res.data['ultimas_reservas'] ?? [];
        _loading = false;
      });
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

    final vertical   = _reservas.take(_verticalCount).toList();
    final carrusel   = _reservas.skip(_verticalCount).toList();
    final hayCarrusel = carrusel.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ────────────────────────────────────────────
          Row(children: [
            const Text('Últimas Reservas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            Text('${_reservas.length} registros',
                style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
            const SizedBox(width: 8),
            GestureDetector(onTap: _cargar,
                child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
          ]),
          const SizedBox(height: 12),

          // ── Cards verticales (primeros 7) ─────────────────────
          ...vertical.map((r) => _cardReserva(r, margin: const EdgeInsets.only(bottom: 8))),

          // ── Indicador de carrusel ─────────────────────────────
          if (hayCarrusel) ...[
            const SizedBox(height: 16),
            _indicadorCarrusel(carrusel.length),
            const SizedBox(height: 10),

            // ── Carrusel horizontal ───────────────────────────
            SizedBox(
              height: 110,
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: carrusel.length,
                onPageChanged: (p) => setState(() => _carouselPage = p),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _cardReserva(carrusel[i]),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Dots ─────────────────────────────────────────
            _dots(carrusel.length, _carouselPage),
          ],
        ]),
      ),
    );
  }

  Widget _cardReserva(dynamic r, {EdgeInsets margin = EdgeInsets.zero}) {
    final color = _colorEstado(r['estado']);
    return Container(
      margin: margin,
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

  Widget _indicadorCarrusel(int cantidad) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.verde.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.verde.withOpacity(0.2)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.swipe, color: AppColors.verde, size: 16),
      const SizedBox(width: 8),
      Text('Desliza para ver $cantidad registro${cantidad > 1 ? 's' : ''} más',
          style: const TextStyle(fontSize: 12, color: AppColors.verde, fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      const Icon(Icons.arrow_forward, color: AppColors.verde, size: 14),
    ]),
  );

  Widget _dots(int total, int current) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(total, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: i == current ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: i == current ? AppColors.verde : AppColors.borde,
        borderRadius: BorderRadius.circular(3),
      ),
    )),
  );
}
