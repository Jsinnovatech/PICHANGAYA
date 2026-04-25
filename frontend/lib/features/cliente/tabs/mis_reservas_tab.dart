import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/models/reserva_model.dart';

class MisReservasTab extends StatefulWidget {
  const MisReservasTab({super.key});
  @override
  State<MisReservasTab> createState() => _MisReservasTabState();
}

class _MisReservasTabState extends State<MisReservasTab> {
  List<ReservaModel> _reservas = [];
  bool _loading = true;
  String? _error;
  int _page = 0;

  static const double _overhead    = 240.0; // appbar + bottomnav + header + paginacion
  static const double _cardHeight  = 155.0; // card con/sin botón cancelar

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

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
      final res = await ApiClient().dio.get(ApiConstants.misReservas);
      setState(() {
        _reservas =
            (res.data as List).map((j) => ReservaModel.fromJson(j)).toList();
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar reservas';
        _loading = false;
      });
    }
  }

  Future<void> _cancelarReserva(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: const Text('¿Cancelar reserva?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: AppColors.texto2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('No', style: TextStyle(color: AppColors.texto2))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rojo,
                  foregroundColor: Colors.white),
              child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient().dio.patch('/reservas/$id/cancelar');
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Reserva cancelada correctamente'),
          backgroundColor: Color(0xFF1B5E20),
        ));
      }
    } on DioException catch (e) {
      String msg = e.response?.data?['detail']?.toString()
          ?? 'Error al cancelar la reserva';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.rojo,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error inesperado al cancelar'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]));
    }

    final ps    = _pageSize(context);
    final total = (_reservas.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _reservas.skip(page * ps).take(ps).toList();

    return Column(children: [
      // ── Header ─────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(bottom: BorderSide(color: AppColors.borde)),
        ),
        child: Row(children: [
          const Text('📋 MIS RESERVAS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.5)),
          const Spacer(),
          if (_reservas.isNotEmpty)
            Text('(${_reservas.length} reservas)',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          const SizedBox(width: 12),
          GestureDetector(
              onTap: _cargar,
              child: const Icon(Icons.refresh, color: AppColors.texto2, size: 20)),
        ]),
      ),

      // ── Contenido ──────────────────────────────────────────
      if (_reservas.isEmpty)
        const Expanded(child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('📋', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No tienes reservas aún',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Ve al mapa y reserva una cancha',
                style: TextStyle(color: AppColors.texto2, fontSize: 12)),
          ]),
        ))
      else ...[
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            color: AppColors.verde,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              itemCount: items.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _cardReserva(items[i]),
              ),
            ),
          ),
        ),
        if (total > 1) ...[
          _paginacion(total, page),
          const SizedBox(height: 8),
        ],
      ],
    ]);
  }

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0,
          () => setState(() => _page = current - 1)),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
      if (total > 9)
        Text('${current + 1} / $total',
            style: const TextStyle(color: AppColors.verde, fontSize: 14, fontWeight: FontWeight.w700)),
      _arrowBtn(Icons.arrow_forward_ios, current < total - 1,
          () => setState(() => _page = current + 1)),
    ]),
  );

  Widget _pageNum(int i, int current) => GestureDetector(
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

  // ── CARD DE RESERVA ───────────────────────────────────────────
  Widget _cardReserva(ReservaModel r) {
    final esPendiente = r.estado == 'pending';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _colorEstado(r.estado).withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _colorEstado(r.estado).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: código + badge
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Text(r.codigo,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5)),
            const Spacer(),
            _badgeEstado(r.estado),
          ]),
        ),

        const SizedBox(height: 10),
        const Divider(color: AppColors.borde, height: 1),

        // Fila 1: Cancha · Local · Fecha
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _col(
                    'CANCHA',
                    Row(children: [
                      const Icon(Icons.sports_soccer,
                          color: AppColors.texto2, size: 11),
                      const SizedBox(width: 3),
                      Flexible(
                          child: Text(r.canchaNombre ?? '—',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]))),
            Expanded(
                child: _col(
                    'LOCAL',
                    Row(children: [
                      const Icon(Icons.location_on,
                          color: AppColors.texto2, size: 11),
                      const SizedBox(width: 3),
                      Flexible(
                          child: Text(r.localNombre ?? '—',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]))),
            _col(
                'FECHA',
                Row(children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.texto2, size: 10),
                  const SizedBox(width: 3),
                  Flexible(
                      child: Text(r.fecha,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white))),
                ])),
          ]),
        ),

        // Fila 2: Hora · Monto · Pago
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _col(
                'HORA',
                Row(children: [
                  const Icon(Icons.access_time,
                      color: AppColors.texto2, size: 11),
                  const SizedBox(width: 3),
                  Text(r.horaInicio,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ])),
            _col(
                'MONTO',
                Text('S/. ${r.precioTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.verde))),
            Expanded(
                child: _col(
                    'PAGO',
                    Text(r.metodoPago ?? '—',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white)))),
          ]),
        ),

        // Botón cancelar
        if (esPendiente) ...[
          const Divider(color: AppColors.borde, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: GestureDetector(
              onTap: () => _cancelarReserva(r.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.rojo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.rojo.withOpacity(0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close, color: AppColors.rojo, size: 13),
                  SizedBox(width: 5),
                  Text('Cancelar',
                      style: TextStyle(
                          color: AppColors.rojo,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 10),
      ]),
    );
  }

  Widget _col(String label, Widget content) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.texto2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          content,
        ]),
      );

  Widget _badgeEstado(String estado) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _colorEstado(estado).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _colorEstado(estado).withOpacity(0.4)),
        ),
        child: Text(_labelEstado(estado),
            style: TextStyle(
                fontSize: 9,
                color: _colorEstado(estado),
                fontWeight: FontWeight.w700)),
      );

  Color _colorEstado(String e) {
    switch (e) {
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

  String _labelEstado(String e) {
    switch (e) {
      case 'confirmed':
        return 'CONFIRMADA';
      case 'pending':
        return 'PENDIENTE';
      case 'active':
        return 'ACTIVA';
      case 'done':
        return 'COMPLETADA';
      case 'canceled':
        return 'CANCELADA';
      default:
        return e.toUpperCase();
    }
  }
}
