import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/models/local_model.dart';
import 'package:pichangaya/shared/models/cancha_model.dart';
import 'package:pichangaya/shared/modals/reserva_modal.dart';

class CanchasTab extends StatefulWidget {
  final LocalModel? localFiltro;
  final String nombreCliente;
  final String celularCliente;
  final String dniCliente;
  const CanchasTab({
    super.key,
    this.localFiltro,
    this.nombreCliente = '',
    this.celularCliente = '',
    this.dniCliente = '',
  });
  @override
  State<CanchasTab> createState() => _CanchasTabState();
}

class _CanchasTabState extends State<CanchasTab> {
  List<CanchaModel> _canchas      = [];
  bool _loading                   = false;
  String? _error;
  CanchaModel? _canchaSeleccionada;
  DateTime _fechaSeleccionada     = DateTime.now();
  List<Map<String, dynamic>> _horarios = [];
  bool _loadingHorarios           = false;
  Map<String, dynamic>? _slotSeleccionado;

  // ── Duración ────────────────────────────────────────────────
  // 1.0 = 1h | 1.5 = 1½h | 2.0 = 2h | 16.0 = todo el día
  double _duracionHoras = 1.0;
  bool get _esTodoDia => _duracionHoras == 16.0;

  @override
  void initState() {
    super.initState();
    _cargarCanchas();
  }

  @override
  void didUpdateWidget(CanchasTab old) {
    super.didUpdateWidget(old);
    if (old.localFiltro?.id != widget.localFiltro?.id) {
      _canchaSeleccionada  = null;
      _slotSeleccionado    = null;
      _duracionHoras       = 1.0;
      _cargarCanchas();
    }
  }

  // ── Helpers de duración ─────────────────────────────────────

  String _calcHoraFin(String horaInicio) {
    if (_esTodoDia) return '00:00'; // medianoche = fin del día
    final parts = horaInicio.split(':');
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    int total = h * 60 + m + (_duracionHoras * 60).round();
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  double _precioParaDur(double precioHora, [double? horas]) {
    final h = horas ?? _duracionHoras;
    return precioHora * h;
  }

  // Slot seleccionable para la duración activa
  bool _slotSeleccionable(int i) {
    if (_esTodoDia) return false;
    if (_horarios[i]['disponible'] != true) return false;
    if (_duracionHoras > 1.0) {
      // 1.5h y 2h requieren el slot actual + el siguiente libres
      if (i + 1 >= _horarios.length) return false;
      if (_horarios[i + 1]['disponible'] != true) return false;
    }
    return true;
  }

  bool get _todoDiaDisponible =>
      _horarios.isNotEmpty &&
      _horarios.every((h) => h['disponible'] == true);

  // ── Carga de datos ──────────────────────────────────────────

  Future<void> _cargarCanchas() async {
    if (widget.localFiltro == null) {
      setState(() { _canchas = []; _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient()
          .dio
          .get('${ApiConstants.locales}/${widget.localFiltro!.id}/canchas');
      setState(() {
        _canchas = (res.data as List).map((j) => CanchaModel.fromJson(j)).toList();
        _loading = false;
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString()
          ?? e.message
          ?? 'Error al cargar canchas';
      setState(() { _error = msg; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error inesperado: $e'; _loading = false; });
    }
  }

  Future<void> _cargarHorarios(CanchaModel cancha, DateTime fecha) async {
    setState(() { _loadingHorarios = true; _horarios = []; _slotSeleccionado = null; });
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);
      final res = await ApiClient().dio.get(
        '${ApiConstants.locales}/${widget.localFiltro!.id}/canchas/${cancha.id}/disponibilidad',
        queryParameters: {'fecha': fechaStr},
      );
      setState(() {
        _horarios = List<Map<String, dynamic>>.from(res.data);
        _loadingHorarios = false;
      });
    } catch (_) {
      setState(() { _loadingHorarios = false; });
    }
  }

  void _seleccionarCancha(CanchaModel cancha) {
    setState(() {
      if (_canchaSeleccionada?.id == cancha.id) {
        _canchaSeleccionada = null;
        _horarios           = [];
        _slotSeleccionado   = null;
        _duracionHoras      = 1.0;
      } else {
        _canchaSeleccionada = cancha;
        _slotSeleccionado   = null;
        _duracionHoras      = 1.0;
      }
    });
    if (_canchaSeleccionada != null)
      _cargarHorarios(cancha, _fechaSeleccionada);
  }

  // ── Build principal ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        if (widget.localFiltro != null) _buildLocalBanner(),
        Expanded(child: _buildContenido()),
      ]),
      if (_slotSeleccionado != null && _canchaSeleccionada != null)
        _buildCTAFlotante(),
    ]);
  }

  // ── Banner del local ────────────────────────────────────────

  Widget _buildLocalBanner() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: const BoxDecoration(
      color: AppColors.negro2,
      border: Border(bottom: BorderSide(color: AppColors.borde)),
    ),
    child: Row(children: [
      const Icon(Icons.sports_soccer, color: AppColors.verde, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.localFiltro!.nombre,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(widget.localFiltro!.direccion,
            style: const TextStyle(fontSize: 11, color: AppColors.texto2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      if (widget.localFiltro?.distanciaKm != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.verde.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.localFiltro!.distanciaKm! < 1
                ? '${(widget.localFiltro!.distanciaKm! * 1000).toInt()}m'
                : '${widget.localFiltro!.distanciaKm!.toStringAsFixed(1)}km',
            style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w700)),
        ),
    ]),
  );

  // ── Contenido (lista de canchas) ────────────────────────────

  Widget _buildContenido() {
    if (widget.localFiltro == null)
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.map_outlined, color: AppColors.texto2, size: 48),
        SizedBox(height: 16),
        Text('Selecciona un local desde el mapa',
            style: TextStyle(color: AppColors.texto2, fontSize: 15)),
        SizedBox(height: 8),
        Text('Toca un marcador verde para ver sus canchas',
            style: TextStyle(color: AppColors.texto2, fontSize: 12)),
      ]));
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null)
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));
    if (_canchas.isEmpty)
      return const Center(child: Text('No hay canchas disponibles',
          style: TextStyle(color: AppColors.texto2)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
      itemCount: _canchas.length,
      itemBuilder: (_, i) {
        final cancha = _canchas[i];
        final sel = _canchaSeleccionada?.id == cancha.id;
        return Column(children: [
          _buildCanchaCard(cancha, sel),
          if (sel) _buildCanchaExpandida(cancha),
        ]);
      },
    );
  }

  // ── Card de cancha (colapsado) ──────────────────────────────

  Widget _buildCanchaCard(CanchaModel cancha, bool sel) => GestureDetector(
    onTap: () => _seleccionarCancha(cancha),
    child: Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sel ? AppColors.negro3 : AppColors.negro2,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: Radius.circular(sel ? 0 : 10),
          bottomRight: Radius.circular(sel ? 0 : 10),
        ),
        border: Border.all(color: sel ? AppColors.verde : AppColors.borde),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.sports_soccer, color: AppColors.verde, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cancha.nombre,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Row(children: [
            _chip(cancha.superficie ?? 'Gras Sintético', AppColors.texto2),
            const SizedBox(width: 6),
            _chip('${cancha.capacidad} jugadores', AppColors.texto2),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (cancha.precioDia != null || cancha.precioNoche != null) ...[
            if (cancha.precioDia != null)
              Text('☀️ S/.${cancha.precioDia!.toStringAsFixed(0)}/h',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFFC107))),
            if (cancha.precioNoche != null)
              Text('🌙 S/.${cancha.precioNoche!.toStringAsFixed(0)}/h',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7986CB))),
          ] else ...[
            Text('S/.${cancha.precioHora.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.verde)),
            const Text('/hora', style: TextStyle(fontSize: 10, color: AppColors.texto2)),
          ],
        ]),
        const SizedBox(width: 8),
        Icon(sel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: AppColors.texto2, size: 20),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════════════
  // SECCIÓN EXPANDIDA — visual + duración + horarios
  // ══════════════════════════════════════════════════════════════

  Widget _buildCanchaExpandida(CanchaModel cancha) => Container(
    decoration: BoxDecoration(
      color: AppColors.negro3,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
      border: const Border(
        left: BorderSide(color: AppColors.verde),
        right: BorderSide(color: AppColors.verde),
        bottom: BorderSide(color: AppColors.verde),
      ),
    ),
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(children: [

      // ── 1. VISUAL DE CANCHA ──────────────────────────────────
      _buildCanchaVisual(cancha),

      // ── 2. SELECTOR DE DURACIÓN ─────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Horas de alquiler',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.texto2, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          _buildDuracionSelector(cancha),
        ]),
      ),

      // ── 3. FECHA + SLOTS ────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildDateTabs(),
          const SizedBox(height: 12),
          _buildHorariosGrid(),
          _buildResumenInline(cancha),
        ]),
      ),
    ]),
  );

  // ── Visual SVG de la cancha ─────────────────────────────────

  Widget _buildCanchaVisual(CanchaModel cancha) => Stack(children: [
    ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(0),
        topRight: Radius.circular(0),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: CustomPaint(painter: _CanchaFieldPainter()),
      ),
    ),
    // Badge tipo (esquina superior izquierda)
    Positioned(
      top: 10, left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${cancha.superficie ?? 'Gras Sintético'} · ${cancha.capacidad}v${cancha.capacidad ~/ 2}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    ),
    // Badge disponible (esquina superior derecha)
    Positioned(
      top: 10, right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.verde.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Disponible',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      ),
    ),
    // Nombre + precio en la parte inferior
    Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.75), Colors.transparent],
          ),
        ),
        child: Row(children: [
          Text(cancha.nombre,
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('S/.${cancha.precioHora.toStringAsFixed(0)}',
              style: const TextStyle(color: AppColors.verde, fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const Text('/h', style: TextStyle(color: AppColors.texto2, fontSize: 11)),
        ]),
      ),
    ),
  ]);

  // ── Selector de duración ────────────────────────────────────

  Widget _buildDuracionSelector(CanchaModel cancha) {
    const opciones = [
      (1.0, '1h',  'Una hora'),
      (1.5, '1½h', 'Hora y media'),
      (2.0, '2h',  'Dos horas'),
    ];

    return Column(children: [
      // Chips 1h / 1½h / 2h
      Row(children: opciones.map((o) {
        final sel = _duracionHoras == o.$1 && !_esTodoDia;
        final precio = _precioParaDur(cancha.precioHora, o.$1);
        return Expanded(child: GestureDetector(
          onTap: () => setState(() {
            _duracionHoras    = o.$1;
            _slotSeleccionado = null;
          }),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.verde.withOpacity(0.12) : AppColors.negro2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? AppColors.verde : AppColors.borde,
                  width: sel ? 1.5 : 1),
            ),
            child: Column(children: [
              Text(o.$2, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: sel ? AppColors.verde : Colors.white)),
              const SizedBox(height: 2),
              Text(o.$3, style: const TextStyle(fontSize: 9, color: AppColors.texto2)),
              const SizedBox(height: 3),
              Text('S/.${precio.toStringAsFixed(0)}', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: sel ? AppColors.verde : AppColors.texto2)),
            ]),
          ),
        ));
      }).toList()),

      const SizedBox(height: 8),

      // Botón Todo el día
      GestureDetector(
        onTap: () {
          if (!_todoDiaDisponible && !_esTodoDia) return;
          setState(() {
            _duracionHoras = 16.0;
            _slotSeleccionado = _todoDiaDisponible
                ? {'hora_inicio': '08:00', 'hora_fin': '23:59', 'disponible': true}
                : null;
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _esTodoDia
                ? AppColors.verde.withOpacity(0.12)
                : !_todoDiaDisponible && _horarios.isNotEmpty
                    ? AppColors.negro2.withOpacity(0.5)
                    : AppColors.negro2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _esTodoDia
                  ? AppColors.verde
                  : !_todoDiaDisponible && _horarios.isNotEmpty
                      ? AppColors.borde.withOpacity(0.4)
                      : AppColors.borde,
              width: _esTodoDia ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Icon(Icons.wb_sunny_outlined,
                color: _esTodoDia ? AppColors.verde : AppColors.texto2, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Todo el día  ·  08:00 → 00:00',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _esTodoDia
                        ? AppColors.verde
                        : !_todoDiaDisponible && _horarios.isNotEmpty
                            ? AppColors.texto2
                            : Colors.white,
                  )),
              Text(
                !_todoDiaDisponible && _horarios.isNotEmpty
                    ? '16 horas · No disponible hoy'
                    : '16 horas · Ideal para eventos y empresas',
                style: const TextStyle(fontSize: 10, color: AppColors.texto2)),
            ])),
            Text(
              'S/.${_precioParaDur(cancha.precioHora, 16.0).toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: _esTodoDia ? AppColors.verde : AppColors.texto2)),
          ]),
        ),
      ),
    ]);
  }

  // ── Tabs de fecha (7 días) ──────────────────────────────────

  Widget _buildDateTabs() => SizedBox(
    height: 52,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 7,
      itemBuilder: (_, i) {
        final fecha = DateTime.now().add(Duration(days: i));
        final sel = DateFormat('yyyy-MM-dd').format(fecha) ==
            DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
        return GestureDetector(
          onTap: () {
            setState(() { _fechaSeleccionada = fecha; _slotSeleccionado = null; });
            _cargarHorarios(_canchaSeleccionada!, fecha);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.verde.withOpacity(0.2) : AppColors.negro2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? AppColors.verde : AppColors.borde),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                i == 0 ? 'Hoy' : i == 1 ? 'Mañ' : DateFormat('EEE', 'es').format(fecha),
                style: TextStyle(
                    fontSize: 10,
                    color: sel ? AppColors.verde : AppColors.texto2,
                    fontWeight: FontWeight.w600)),
              Text(DateFormat('d MMM', 'es').format(fecha),
                  style: TextStyle(
                      fontSize: 12,
                      color: sel ? AppColors.verde : Colors.white,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    ),
  );

  // ── Grid de slots ───────────────────────────────────────────

  Widget _buildHorariosGrid() {
    if (_loadingHorarios)
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.verde, strokeWidth: 2)));
    if (_horarios.isEmpty)
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay horarios para esta fecha',
                style: TextStyle(color: AppColors.texto2, fontSize: 13))));

    // Cuando está en modo "todo el día", no mostramos el grid
    if (_esTodoDia) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _todoDiaDisponible
              ? AppColors.verde.withOpacity(0.08)
              : AppColors.rojo.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _todoDiaDisponible
                  ? AppColors.verde.withOpacity(0.4)
                  : AppColors.rojo.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(
            _todoDiaDisponible ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: _todoDiaDisponible ? AppColors.verde : AppColors.rojo,
            size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _todoDiaDisponible
                ? 'La cancha está libre todo el día. ¡Reserva confirmada al hacer tap en el botón!'
                : 'La cancha no está disponible todo el día para esta fecha.',
            style: TextStyle(
                fontSize: 13,
                color: _todoDiaDisponible ? AppColors.verde : AppColors.rojo),
          )),
        ]),
      );
    }

    // Grid normal con slots horarios — 3 columnas exactas con LayoutBuilder
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = (constraints.maxWidth - 12) / 3; // 2 gaps × 6px
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(_horarios.length, (i) {
            final h          = _horarios[i];
            final horaInicio = h['hora_inicio']?.toString().substring(0, 5) ?? '';
            final disponible = _slotSeleccionable(i);
            final ocupado    = h['disponible'] != true;
            final sel        = _slotSeleccionado?['hora_inicio'] == h['hora_inicio'];
            final horaFin    = sel ? _calcHoraFin(horaInicio) : '';

            return GestureDetector(
              onTap: disponible ? () => setState(() {
                _slotSeleccionado = sel ? null : h;
              }) : null,
              child: Container(
                width: slotWidth,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: ocupado
                      ? AppColors.negro2
                      : sel
                          ? AppColors.verde
                          : disponible
                              ? AppColors.verde.withOpacity(0.08)
                              : AppColors.negro2.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ocupado
                        ? AppColors.borde.withOpacity(0.4)
                        : sel
                            ? AppColors.verde
                            : disponible
                                ? AppColors.verde.withOpacity(0.35)
                                : AppColors.borde.withOpacity(0.3),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(horaInicio, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: ocupado
                        ? AppColors.texto2
                        : sel
                            ? AppColors.negro
                            : disponible
                                ? AppColors.verde
                                : AppColors.texto2.withOpacity(0.5),
                    decoration: ocupado ? TextDecoration.lineThrough : null,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    ocupado
                        ? 'Ocupado'
                        : sel
                            ? '→ $horaFin'
                            : _duracionHoras == 1.0
                                ? '1h'
                                : _duracionHoras == 1.5
                                    ? '1h 30m'
                                    : '2h',
                    style: TextStyle(
                      fontSize: 10,
                      color: ocupado
                          ? AppColors.texto2.withOpacity(0.5)
                          : sel
                              ? AppColors.negro.withOpacity(0.7)
                              : AppColors.texto2,
                    ),
                  ),
                ]),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Resumen inline (aparece al seleccionar slot) ────────────

  Widget _buildResumenInline(CanchaModel cancha) {
    if (_slotSeleccionado == null) return const SizedBox.shrink();

    final horaInicio = _slotSeleccionado!['hora_inicio']?.toString().substring(0, 5) ?? '';
    final horaFin    = _calcHoraFin(horaInicio);
    final precio     = _precioParaDur(cancha.precioHora);
    final durLabel   = _esTodoDia
        ? '16 horas (todo el día)'
        : _duracionHoras == 1.5
            ? '1 hora 30 min'
            : '${_duracionHoras.toInt()} ${_duracionHoras == 1 ? 'hora' : 'horas'}';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verde.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.verde.withOpacity(0.35)),
      ),
      child: Column(children: [
        _filaResumen('Cancha',   cancha.nombre),
        _filaResumen('Horario',  '$horaInicio – $horaFin'),
        _filaResumen('Duración', durLabel),
        const Divider(color: AppColors.borde, height: 16),
        Row(children: [
          const Text('Total', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          Text('S/.${precio.toStringAsFixed(0)}', style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.verde)),
        ]),
      ]),
    );
  }

  Widget _filaResumen(String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
      const Spacer(),
      Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    ]),
  );

  // ── CTA flotante ────────────────────────────────────────────

  Widget _buildCTAFlotante() {
    final horaInicio = _slotSeleccionado!['hora_inicio']?.toString().substring(0, 5) ?? '';
    final horaFin    = _calcHoraFin(horaInicio);
    final fechaStr   = DateFormat('d MMM', 'es').format(_fechaSeleccionada);
    final precio     = _precioParaDur(_canchaSeleccionada!.precioHora);

    return Positioned(
      left: 12, right: 12, bottom: 16,
      child: GestureDetector(
        onTap: _mostrarModalReservar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.verde,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: AppColors.verde.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_canchaSeleccionada!.nombre} · $horaInicio – $horaFin',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.negro)),
              Text('$fechaStr · ${_esTodoDia ? 'Todo el día' : '${_duracionHoras == 1.5 ? "1h 30m" : "${_duracionHoras.toInt()}h"}'}',
                  style: TextStyle(fontSize: 12, color: AppColors.negro.withOpacity(0.7))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.negro, borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                const Text('Reservar', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.verde)),
                Text('S/.${precio.toStringAsFixed(0)}', style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.verde)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Modal de reserva ────────────────────────────────────────

  Future<void> _mostrarModalReservar() async {
    if (_slotSeleccionado == null || _canchaSeleccionada == null) return;

    final horaInicio = _slotSeleccionado!['hora_inicio']?.toString().substring(0, 5) ?? '';
    final horaFin    = _calcHoraFin(horaInicio);

    // Usar datos cargados en ClientShell al iniciar sesión (evita usar
    // /auth/me aquí porque en web localStorage es compartido entre tabs
    // y podría devolver datos de otro rol abierto en otra pestaña).
    final nombre   = widget.nombreCliente;
    final telefono = widget.celularCliente.isNotEmpty
        ? '+51 ${widget.celularCliente}'
        : '';
    final dni      = widget.dniCliente;

    if (!mounted) return;

    await ReservaModal.show(
      context,
      canchaId:        _canchaSeleccionada!.id,
      canchaName:      _canchaSeleccionada!.nombre,
      localName:       widget.localFiltro!.nombre,
      localId:         widget.localFiltro!.id,
      fecha:           _fechaSeleccionada,
      horaInicio:      horaInicio,
      horaFin:         horaFin,
      precioTotal:     _precioParaDur(_canchaSeleccionada!.precioHora),
      nombreInicial:   nombre,
      telefonoInicial: telefono,
      dniInicial:      dni,
      onReservado: () {
        setState(() => _slotSeleccionado = null);
        _cargarHorarios(_canchaSeleccionada!, _fechaSeleccionada);
      },
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color)),
  );
}

// ══════════════════════════════════════════════════════════════
// PAINTER — CAMPO DE FÚTBOL
// ══════════════════════════════════════════════════════════════

class _CanchaFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = true;

    // Fondo verde con bandas
    p.color = const Color(0xFF1D7A42);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);

    p.color = const Color(0xFF1A7040);
    final bw = size.width / 8;
    for (int i = 0; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * bw, 0, bw, size.height), p);
    }

    const pad = 14.0;

    // Línea exterior
    p
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad), p);

    // Línea central vertical
    p..color = Colors.white.withOpacity(0.45)..strokeWidth = 1.0;
    canvas.drawLine(
        Offset(size.width / 2, pad), Offset(size.width / 2, size.height - pad), p);

    // Círculo central
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.21, p);

    // Punto central
    p.style = PaintingStyle.fill;
    p.color = Colors.white.withOpacity(0.7);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2.5, p);

    // Área de penalti izquierda
    p
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.5;
    final laW = size.width * 0.13;
    final laH = size.height * 0.5;
    final laTop = (size.height - laH) / 2;
    canvas.drawRect(Rect.fromLTRB(pad, laTop, pad + laW, laTop + laH), p);

    // Área de penalti derecha
    canvas.drawRect(
        Rect.fromLTRB(size.width - pad - laW, laTop, size.width - pad, laTop + laH), p);

    // Área chica izquierda
    p..color = Colors.white.withOpacity(0.4)..strokeWidth = 1.0;
    final gbW = size.width * 0.055;
    final gbH = size.height * 0.3;
    final gbTop = (size.height - gbH) / 2;
    canvas.drawRect(Rect.fromLTRB(pad, gbTop, pad + gbW, gbTop + gbH), p);

    // Área chica derecha
    canvas.drawRect(
        Rect.fromLTRB(size.width - pad - gbW, gbTop, size.width - pad, gbTop + gbH), p);

    // Arcos de esquinas
    final cp = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const cr = 7.0;
    canvas.drawArc(Rect.fromLTWH(pad - cr, pad - cr, cr * 2, cr * 2), 0, math.pi / 2, false, cp);
    canvas.drawArc(Rect.fromLTWH(size.width - pad - cr, pad - cr, cr * 2, cr * 2), math.pi / 2, math.pi / 2, false, cp);
    canvas.drawArc(Rect.fromLTWH(pad - cr, size.height - pad - cr, cr * 2, cr * 2), -math.pi / 2, -math.pi / 2, false, cp);
    canvas.drawArc(Rect.fromLTWH(size.width - pad - cr, size.height - pad - cr, cr * 2, cr * 2), 0, -math.pi / 2, false, cp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// Los modales de reserva y pago están en:
//   lib/shared/modals/reserva_modal.dart  →  ReservaModal
//   lib/shared/modals/pago_modal.dart     →  PagoModal
