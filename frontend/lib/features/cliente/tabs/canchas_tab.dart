import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/models/local_model.dart';
import 'package:pichangaya/shared/models/cancha_model.dart';
import 'dart:typed_data';

class CanchasTab extends StatefulWidget {
  final LocalModel? localFiltro;
  const CanchasTab({super.key, this.localFiltro});
  @override
  State<CanchasTab> createState() => _CanchasTabState();
}

class _CanchasTabState extends State<CanchasTab> {
  List<CanchaModel> _canchas = [];
  bool _loading = false;
  String? _error;
  CanchaModel? _canchaSeleccionada;
  DateTime _fechaSeleccionada = DateTime.now();
  List<Map<String, dynamic>> _horarios = [];
  bool _loadingHorarios = false;
  Map<String, dynamic>? _slotSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarCanchas();
  }

  @override
  void didUpdateWidget(CanchasTab old) {
    super.didUpdateWidget(old);
    if (old.localFiltro?.id != widget.localFiltro?.id) {
      _canchaSeleccionada = null;
      _slotSeleccionado = null;
      _cargarCanchas();
    }
  }

  Future<void> _cargarCanchas() async {
    if (widget.localFiltro == null) {
      setState(() {
        _canchas = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient()
          .dio
          .get('${ApiConstants.locales}/${widget.localFiltro!.id}/canchas');
      setState(() {
        _canchas =
            (res.data as List).map((j) => CanchaModel.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar canchas';
        _loading = false;
      });
    }
  }

  Future<void> _cargarHorarios(CanchaModel cancha, DateTime fecha) async {
    setState(() {
      _loadingHorarios = true;
      _horarios = [];
      _slotSeleccionado = null;
    });
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
    } catch (e) {
      setState(() {
        _loadingHorarios = false;
      });
    }
  }

  void _seleccionarCancha(CanchaModel cancha) {
    setState(() {
      if (_canchaSeleccionada?.id == cancha.id) {
        _canchaSeleccionada = null;
        _horarios = [];
        _slotSeleccionado = null;
      } else {
        _canchaSeleccionada = cancha;
        _slotSeleccionado = null;
      }
    });
    if (_canchaSeleccionada != null)
      _cargarHorarios(cancha, _fechaSeleccionada);
  }

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

  Widget _buildLocalBanner() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(bottom: BorderSide(color: AppColors.borde)),
        ),
        child: Row(children: [
          const Icon(Icons.sports_soccer, color: AppColors.verde, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.localFiltro!.nombre,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(widget.localFiltro!.direccion,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.texto2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.verde,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      );

  Widget _buildContenido() {
    if (widget.localFiltro == null)
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.map_outlined, color: AppColors.texto2, size: 48),
          SizedBox(height: 16),
          Text('Selecciona un local desde el mapa',
              style: TextStyle(color: AppColors.texto2, fontSize: 15)),
          SizedBox(height: 8),
          Text('Toca un marcador verde para ver sus canchas',
              style: TextStyle(color: AppColors.texto2, fontSize: 12)),
        ],
      ));
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null)
      return Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));
    if (_canchas.isEmpty)
      return const Center(
          child: Text('No hay canchas disponibles',
              style: TextStyle(color: AppColors.texto2)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _canchas.length,
      itemBuilder: (_, i) {
        final cancha = _canchas[i];
        final sel = _canchaSeleccionada?.id == cancha.id;
        return Column(children: [
          _buildCanchaCard(cancha, sel),
          if (sel) _buildHorariosInline(cancha),
        ]);
      },
    );
  }

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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.verde.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.sports_soccer,
                  color: AppColors.verde, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(cancha.nombre,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _chip(cancha.superficie ?? 'Gras Sintético',
                        AppColors.texto2),
                    const SizedBox(width: 6),
                    _chip('${cancha.capacidad} jugadores', AppColors.texto2),
                  ]),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('S/.${cancha.precioHora.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.verde)),
              const Text('/hora',
                  style: TextStyle(fontSize: 10, color: AppColors.texto2)),
            ]),
            const SizedBox(width: 8),
            Icon(sel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.texto2, size: 20),
          ]),
        ),
      );

  Widget _buildHorariosInline(CanchaModel cancha) => Container(
        decoration: BoxDecoration(
          color: AppColors.negro3,
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10)),
          border: Border.all(color: AppColors.verde),
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildDateTabs(),
          const SizedBox(height: 12),
          _buildHorariosGrid(),
        ]),
      );

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
                setState(() {
                  _fechaSeleccionada = fecha;
                  _slotSeleccionado = null;
                });
                _cargarHorarios(_canchaSeleccionada!, fecha);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      sel ? AppColors.verde.withOpacity(0.2) : AppColors.negro2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? AppColors.verde : AppColors.borde),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          i == 0
                              ? 'Hoy'
                              : i == 1
                                  ? 'Mañ'
                                  : DateFormat('EEE', 'es').format(fecha),
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

  Widget _buildHorariosGrid() {
    if (_loadingHorarios)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: AppColors.verde, strokeWidth: 2)));
    if (_horarios.isEmpty)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay horarios para esta fecha',
                  style: TextStyle(color: AppColors.texto2, fontSize: 13))));

    return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _horarios.map((h) {
          final disponible = h['disponible'] == true;
          final horaInicio = h['hora_inicio']?.toString().substring(0, 5) ?? '';
          final sel = _slotSeleccionado?['hora_inicio'] == h['hora_inicio'];
          return GestureDetector(
            onTap: disponible
                ? () => setState(() {
                      _slotSeleccionado = sel ? null : h;
                    })
                : null,
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: !disponible
                    ? AppColors.negro2
                    : sel
                        ? AppColors.verde
                        : AppColors.verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: !disponible
                        ? AppColors.borde
                        : sel
                            ? AppColors.verde
                            : AppColors.verde.withOpacity(0.4)),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(horaInicio,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !disponible
                                ? AppColors.texto2
                                : sel
                                    ? AppColors.negro
                                    : AppColors.verde)),
                    if (!disponible)
                      const Text('Ocupado',
                          style:
                              TextStyle(fontSize: 9, color: AppColors.texto2)),
                  ]),
            ),
          );
        }).toList());
  }

  Widget _buildCTAFlotante() {
    final horaInicio =
        _slotSeleccionado?['hora_inicio']?.toString().substring(0, 5) ?? '';
    final horaFin =
        _slotSeleccionado?['hora_fin']?.toString().substring(0, 5) ?? '';
    final fechaStr = DateFormat('d MMM', 'es').format(_fechaSeleccionada);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
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
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${_canchaSeleccionada!.nombre} · $horaInicio - $horaFin',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.negro)),
                  Text(
                      '$fechaStr · S/.${_canchaSeleccionada!.precioHora.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.negro.withOpacity(0.7))),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.negro,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Reservar ➜',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.verde)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _mostrarModalReservar() async {
    if (_slotSeleccionado == null || _canchaSeleccionada == null) return;
    final horaInicio =
        _slotSeleccionado!['hora_inicio']?.toString().substring(0, 5) ?? '';
    final horaFin =
        _slotSeleccionado!['hora_fin']?.toString().substring(0, 5) ?? '';
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

    String nombre = '';
    String telefono = '';
    String dni = '';

    // Primero intentar desde el backend
    try {
      final res = await ApiClient().dio.get('/auth/me');
      if (res.statusCode == 200 && res.data != null) {
        nombre = (res.data['nombre'] ?? '').toString();
        final cel = (res.data['celular'] ?? '').toString();
        telefono = cel.isNotEmpty ? '+51 $cel' : '';
        dni = (res.data['dni'] ?? '').toString();
      }
    } catch (_) {}

    // Si el backend no devolvió datos, leer del storage guardado al login
    if (nombre.isEmpty) {
      try {
        final userJson = await ApiClient().getUserJson();
        if (userJson != null && userJson.isNotEmpty) {
          // Parsear manualmente el JSON simple guardado
          final nombreMatch =
              RegExp(r'"nombre":"([^"]*)"').firstMatch(userJson);
          final celMatch = RegExp(r'"celular":"([^"]*)"').firstMatch(userJson);
          final dniMatch = RegExp(r'"dni":"([^"]*)"').firstMatch(userJson);
          nombre = nombreMatch?.group(1) ?? '';
          final cel = celMatch?.group(1) ?? '';
          telefono = cel.isNotEmpty ? '+51 $cel' : '';
          dni = dniMatch?.group(1) ?? '';
        }
      } catch (_) {}
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ModalReservarCancha(
        cancha: _canchaSeleccionada!,
        local: widget.localFiltro!,
        fecha: fechaStr,
        horaInicio: horaInicio,
        horaFin: horaFin,
        nombreInicial: nombre,
        telefonoInicial: telefono,
        dniInicial: dni,
        onReservado: () {
          setState(() {
            _slotSeleccionado = null;
          });
          _cargarHorarios(_canchaSeleccionada!, _fechaSeleccionada);
        },
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 10, color: color)),
      );
}

// ══════════════════════════════════════════════════════════════
// MODAL PASO 1 — RESERVAR CANCHA
// ══════════════════════════════════════════════════════════════
class _ModalReservarCancha extends StatefulWidget {
  final CanchaModel cancha;
  final LocalModel local;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final String nombreInicial;
  final String telefonoInicial;
  final String dniInicial;
  final VoidCallback onReservado;

  const _ModalReservarCancha({
    required this.cancha,
    required this.local,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.nombreInicial,
    required this.telefonoInicial,
    required this.dniInicial,
    required this.onReservado,
  });
  @override
  State<_ModalReservarCancha> createState() => _ModalReservarCanchaState();
}

class _ModalReservarCanchaState extends State<_ModalReservarCancha> {
  String _metodoPago = 'yape';
  String _tipoDoc = 'boleta';
  bool _loading = false;
  String? _error;
  late final TextEditingController _dniCtrl;

  @override
  void initState() {
    super.initState();
    // Inicializar el campo DNI con el valor precargado
    _dniCtrl = TextEditingController(text: widget.dniInicial);
  }

  @override
  void dispose() {
    _dniCtrl.dispose();
    super.dispose();
  }

  Future<void> _procederAlPago() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.post(ApiConstants.reservas, data: {
        'cancha_id': widget.cancha.id,
        'fecha': widget.fecha,
        'hora_inicio': widget.horaInicio,
        'hora_fin': widget.horaFin,
        'metodo_pago': _metodoPago,
        'tipo_doc': _tipoDoc,
      });
      setState(() {
        _loading = false;
      });
      if (mounted) {
        Navigator.pop(context);
        await showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _ModalRealizarPago(
            metodoPago: _metodoPago,
            monto: widget.cancha.precioHora,
            pagoId: res.data['pago_id']?.toString(),
            onConfirmado: widget.onReservado,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error al crear reserva. El horario puede estar ocupado.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.borde,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          const Text('RESERVAR CANCHA',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.verde,
                  letterSpacing: 0.5)),
          const Spacer(),
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child:
                  const Icon(Icons.close, color: AppColors.texto2, size: 20)),
        ]),
        const SizedBox(height: 16),

        // Info cancha
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borde),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.sports_soccer, color: AppColors.verde, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      '${widget.cancha.nombre} · ${widget.cancha.superficie ?? 'Gras Sintético'}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, color: AppColors.texto2, size: 12),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                      '${widget.local.nombre} · ${widget.local.direccion}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.texto2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today,
                  color: AppColors.texto2, size: 12),
              const SizedBox(width: 6),
              Text(widget.fecha,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.texto2)),
              const SizedBox(width: 12),
              const Icon(Icons.access_time, color: AppColors.texto2, size: 12),
              const SizedBox(width: 6),
              Text('${widget.horaInicio} hrs',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.texto2)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.attach_money, color: AppColors.verde, size: 14),
              Text('S/.${widget.cancha.precioHora.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.verde)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // NOMBRE — solo lectura
        _campoLectura('NOMBRE',
            widget.nombreInicial.isNotEmpty ? widget.nombreInicial : '—'),
        const SizedBox(height: 10),

        // TELÉFONO — solo lectura
        _campoLectura('TELÉFONO',
            widget.telefonoInicial.isNotEmpty ? widget.telefonoInicial : '—'),
        const SizedBox(height: 10),

        // DNI/RUC — EDITABLE
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DNI / RUC',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.texto2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          TextField(
            controller: _dniCtrl,
            keyboardType: TextInputType.number,
            maxLength: 11,
            decoration: const InputDecoration(
              hintText: 'Ingresa tu DNI o RUC',
              counterText: '',
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // Método de pago
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('MÉTODO DE PAGO',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.texto2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5))),
        const SizedBox(height: 8),
        Row(children: [
          ...[
            ('yape', 'Yape', '📱', 'Al instante'),
            ('plin', 'Plin', '💙', 'Al instante'),
            ('transferencia', 'Transfer.', '🏦', 'BCP/BBVA'),
            ('efectivo', 'Efectivo', '💵', 'En el local'),
          ]
              .map((m) => Expanded(
                      child: GestureDetector(
                    onTap: () => setState(() {
                      _metodoPago = m.$1;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _metodoPago == m.$1
                            ? AppColors.verde.withOpacity(0.15)
                            : AppColors.negro3,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _metodoPago == m.$1
                                ? AppColors.verde
                                : AppColors.borde,
                            width: _metodoPago == m.$1 ? 1.5 : 1),
                      ),
                      child: Column(children: [
                        Text(m.$3, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(m.$2,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _metodoPago == m.$1
                                    ? AppColors.verde
                                    : Colors.white)),
                        Text(m.$4,
                            style: const TextStyle(
                                fontSize: 8, color: AppColors.texto2)),
                      ]),
                    ),
                  )))
              .toList(),
        ]),
        const SizedBox(height: 14),

        // Tipo documento
        Row(children: [
          const Text('Doc:',
              style: TextStyle(color: AppColors.texto2, fontSize: 12)),
          const SizedBox(width: 8),
          ...[('boleta', 'Boleta'), ('factura', 'Factura')]
              .map((d) => GestureDetector(
                    onTap: () => setState(() {
                      _tipoDoc = d.$1;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _tipoDoc == d.$1
                            ? AppColors.verde.withOpacity(0.15)
                            : AppColors.negro3,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _tipoDoc == d.$1
                                ? AppColors.verde
                                : AppColors.borde),
                      ),
                      child: Text(d.$2,
                          style: TextStyle(
                              fontSize: 12,
                              color: _tipoDoc == d.$1
                                  ? AppColors.verde
                                  : AppColors.texto2,
                              fontWeight: _tipoDoc == d.$1
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ),
                  ))
              .toList(),
        ]),
        const SizedBox(height: 16),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.rojo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],

        // Botón proceder
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _procederAlPago,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verde,
                foregroundColor: AppColors.negro,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.negro))
                  : const Text('💰 Proceder al Pago',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            )),
      ])),
    );
  }

  Widget _campoLectura(String label, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.texto2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.negro3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borde),
            ),
            child: Text(valor,
                style: const TextStyle(fontSize: 14, color: Colors.white)),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
// MODAL PASO 2 — REALIZAR PAGO + VOUCHER
// ══════════════════════════════════════════════════════════════
class _ModalRealizarPago extends StatefulWidget {
  final String metodoPago;
  final double monto;
  final String? pagoId;
  final VoidCallback onConfirmado;

  const _ModalRealizarPago({
    required this.metodoPago,
    required this.monto,
    required this.pagoId,
    required this.onConfirmado,
  });
  @override
  State<_ModalRealizarPago> createState() => _ModalRealizarPagoState();
}

class _ModalRealizarPagoState extends State<_ModalRealizarPago> {
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  bool _subiendo = false;
  String? _error;

  static const _datosPago = {
    'yape': {
      'numero': '999-888-777',
      'titular': 'PICHANGAYA SAC',
      'icono': '📱'
    },
    'plin': {
      'numero': '999-777-666',
      'titular': 'PICHANGAYA SAC',
      'icono': '💙'
    },
    'transferencia': {
      'numero': '215-12345678-0-01',
      'titular': 'PICHANGAYA SAC (BCP)',
      'icono': '🏦'
    },
    'efectivo': {
      'numero': 'Paga en el local',
      'titular': 'Al momento de jugar',
      'icono': '💵'
    },
  };

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagenBytes = bytes;
      _imagenNombre = picked.name;
      _error = null;
    });
  }

  Future<void> _enviarVoucher() async {
    if (widget.pagoId == null) {
      Navigator.pop(context);
      widget.onConfirmado();
      return;
    }
    if (_imagenBytes == null && widget.metodoPago != 'efectivo') {
      setState(() {
        _error = 'Selecciona una imagen del voucher';
      });
      return;
    }
    setState(() {
      _subiendo = true;
      _error = null;
    });
    try {
      if (widget.metodoPago != 'efectivo' && _imagenBytes != null) {
        final formData = FormData.fromMap({
          'imagen': MultipartFile.fromBytes(_imagenBytes!,
              filename: _imagenNombre ?? 'voucher.jpg',
              contentType: DioMediaType('image', 'jpeg')),
        });
        await ApiClient().dio.post('/pagos/${widget.pagoId}/voucher',
            data: formData,
            options: Options(contentType: 'multipart/form-data'));
      }
      setState(() {
        _subiendo = false;
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onConfirmado();
      }
    } catch (e) {
      setState(() {
        _error = 'Error al enviar voucher. Intenta de nuevo.';
        _subiendo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datosPago[widget.metodoPago] ?? _datosPago['yape']!;
    final esEfectivo = widget.metodoPago == 'efectivo';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.borde,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        Row(children: [
          const Text('REALIZAR PAGO',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.verde,
                  letterSpacing: 0.5)),
          const Spacer(),
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child:
                  const Icon(Icons.close, color: AppColors.texto2, size: 20)),
        ]),
        const SizedBox(height: 16),

        // Datos de pago
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borde),
          ),
          child: Column(children: [
            Text(datos['icono']!, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text('Envía el pago a:',
                style: TextStyle(fontSize: 12, color: AppColors.texto2)),
            const SizedBox(height: 4),
            Text(datos['numero']!,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text(datos['titular']!,
                style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
            const SizedBox(height: 10),
            Text('S/.${widget.monto.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.verde)),
          ]),
        ),
        const SizedBox(height: 16),

        // Voucher
        if (!esEfectivo) ...[
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('SUBIR VOUCHER / CAPTURA',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.texto2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5))),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _seleccionarImagen,
            child: Container(
              width: double.infinity,
              height: _imagenBytes != null ? 140 : 100,
              decoration: BoxDecoration(
                color: AppColors.negro3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _imagenBytes != null
                        ? AppColors.verde
                        : AppColors.borde),
              ),
              child: _imagenBytes != null
                  ? Stack(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_imagenBytes!,
                              width: double.infinity, fit: BoxFit.cover)),
                      Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                              onTap: () => setState(() {
                                    _imagenBytes = null;
                                  }),
                              child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16)))),
                    ])
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Text('📷', style: TextStyle(fontSize: 28)),
                          SizedBox(height: 6),
                          Text('Toca para subir tu comprobante de pago',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.texto2)),
                        ]),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.rojo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],

        // Botón
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _subiendo ? null : _enviarVoucher,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verde,
                foregroundColor: AppColors.negro,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _subiendo
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.negro))
                  : Text(
                      esEfectivo
                          ? '✅ Confirmar Reserva'
                          : '✅ Enviar Voucher y Confirmar',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
            )),
      ]),
    );
  }
}
