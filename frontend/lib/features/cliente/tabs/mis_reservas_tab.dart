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
  final PageController _pageController = PageController();
  int _paginaActual = 0;

  // Cuántas reservas por página
  static const int _porPagina = 3;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Total de páginas según las reservas
  int get _totalPaginas => (_reservas.length / _porPagina).ceil();

  // Reservas de una página específica
  List<ReservaModel> _reservasDePagina(int pagina) {
    final inicio = pagina * _porPagina;
    final fin = (inicio + _porPagina).clamp(0, _reservas.length);
    return _reservas.sublist(inicio, fin);
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
        _paginaActual = 0;
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
    } catch (e) {
      String msg = 'Error al cancelar la reserva';
      if (e.toString().contains('400')) {
        msg = 'Solo puedes cancelar reservas pendientes';
      } else if (e.toString().contains('404')) {
        msg = 'Reserva no encontrada';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5)),
          const Spacer(),
          if (_reservas.isNotEmpty) ...[
            // Muestra página actual / total páginas
            Text('Pág ${_paginaActual + 1} / $_totalPaginas',
                style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
            const SizedBox(width: 4),
            Text('(${_reservas.length} reservas)',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          ],
          const SizedBox(width: 12),
          GestureDetector(
              onTap: _cargar,
              child:
                  const Icon(Icons.refresh, color: AppColors.texto2, size: 20)),
        ]),
      ),

      // ── Contenido ──────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.verde))
            : _error != null
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text(_error!,
                            style: const TextStyle(color: AppColors.rojo)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar')),
                      ]))
                : _reservas.isEmpty
                    ? const Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Text('📋', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text('No tienes reservas aún',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 4),
                            Text('Ve al mapa y reserva una cancha',
                                style: TextStyle(
                                    color: AppColors.texto2, fontSize: 12)),
                          ]))
                    : Column(children: [
                        // ── PageView — cada página tiene 3 reservas ──
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _totalPaginas,
                            onPageChanged: (i) => setState(() {
                              _paginaActual = i;
                            }),
                            itemBuilder: (_, pagina) {
                              final reservasDePagina =
                                  _reservasDePagina(pagina);
                              return _buildPagina(reservasDePagina);
                            },
                          ),
                        ),

                        // ── Indicadores + navegación ──────────────
                        if (_totalPaginas > 1) _buildIndicadores(),
                      ]),
      ),
    ]);
  }

  // Una página con hasta 3 reservas apiladas
  Widget _buildPagina(List<ReservaModel> reservas) {
    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: reservas
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _cardReserva(r),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // Indicadores de página + flechas
  Widget _buildIndicadores() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Row(children: [
        // Flecha anterior
        GestureDetector(
          onTap: () {
            if (_paginaActual > 0) {
              _pageController.previousPage(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut);
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _paginaActual > 0 ? AppColors.negro2 : AppColors.negro3,
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        _paginaActual > 0 ? AppColors.verde : AppColors.borde)),
            child: Icon(Icons.arrow_back_ios_new,
                color: _paginaActual > 0 ? AppColors.verde : AppColors.texto2,
                size: 14),
          ),
        ),

        // Puntos indicadores de página
        Expanded(
            child: Center(
                child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              _totalPaginas,
              (i) => GestureDetector(
                    onTap: () => _pageController.animateToPage(i,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _paginaActual ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: i == _paginaActual
                              ? AppColors.verde
                              : AppColors.borde,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  )),
        ))),

        // Flecha siguiente
        GestureDetector(
          onTap: () {
            if (_paginaActual < _totalPaginas - 1) {
              _pageController.nextPage(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut);
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _paginaActual < _totalPaginas - 1
                    ? AppColors.negro2
                    : AppColors.negro3,
                shape: BoxShape.circle,
                border: Border.all(
                    color: _paginaActual < _totalPaginas - 1
                        ? AppColors.verde
                        : AppColors.borde)),
            child: Icon(Icons.arrow_forward_ios,
                color: _paginaActual < _totalPaginas - 1
                    ? AppColors.verde
                    : AppColors.texto2,
                size: 14),
          ),
        ),
      ]),
    );
  }

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
