import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class AdminReservaManualPage extends StatefulWidget {
  const AdminReservaManualPage({super.key});
  @override
  State<AdminReservaManualPage> createState() => _State();
}

class _State extends State<AdminReservaManualPage> {
  DateTime _fecha         = DateTime.now();
  bool _loading           = false;
  List<dynamic> _canchas  = [];
  String? _error;

  // ── Duración global para todas las canchas ──────────────────
  double _duracionHoras = 1.0;
  bool get _esTodoDia   => _duracionHoras == 16.0;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fecha);
      final res = await ApiClient().dio.get(
        '/admin/disponibilidad-canchas',
        queryParameters: {'fecha': fechaStr},
      );
      setState(() { _canchas = res.data ?? []; _loading = false; });
    } catch (e) {
      String msg = 'Error al cargar disponibilidad';
      if (e is DioException) msg = e.response?.data?['detail']?.toString() ?? msg;
      setState(() { _error = msg; _loading = false; });
    }
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.verde),
        ),
        child: child!,
      ),
    );
    if (picked != null) { setState(() => _fecha = picked); _cargar(); }
  }

  // ── Helpers ─────────────────────────────────────────────────

  double _precioHoraEfectivo(Map<String, dynamic> cancha, String horaInicio) {
    final precioDia   = cancha['precio_dia']?.toDouble();
    final precioNoche = cancha['precio_noche']?.toDouble();
    final precioHora  = cancha['precio_hora']?.toDouble() ?? 0.0;
    if (precioDia == null && precioNoche == null) return precioHora;
    final h = int.parse(horaInicio.split(':')[0]);
    return (h >= 6 && h < 18) ? (precioDia ?? precioHora) : (precioNoche ?? precioHora);
  }

  bool _slotSeleccionable(List<dynamic> slots, int i) {
    if (_esTodoDia) return false;
    if (slots[i]['disponible'] != true) return false;
    if (_duracionHoras > 1.0) {
      if (i + 1 >= slots.length) return false;
      if (slots[i + 1]['disponible'] != true) return false;
    }
    return true;
  }

  bool _todoDiaDisponible(List<dynamic> slots) =>
      slots.isNotEmpty && slots.every((s) => s['disponible'] == true);

  void _abrirModal(Map<String, dynamic> cancha, Map<String, dynamic> slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _ModalReservaManual(
        cancha: cancha,
        slot: slot,
        fecha: _fecha,
        onCreada: _cargar,
        duracionInicial: _duracionHoras,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Selector de fecha
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.negro2,
        child: Row(children: [
          const Icon(Icons.calendar_today, color: AppColors.verde, size: 18),
          const SizedBox(width: 8),
          Text(
            DateFormat('dd-MM-yyyy').format(_fecha),
            style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: _elegirFecha,
            child: const Text('Cambiar', style: TextStyle(color: AppColors.verde)),
          ),
        ]),
      ),

      // Selector de duración global
      _buildSelectorDuracion(),

      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildSelectorDuracion() {
    const opciones = [
      (1.0,  '1h',      'Una hora'),
      (1.5,  '1½h',     'Hora y media'),
      (2.0,  '2h',      'Dos horas'),
    ];

    return Container(
      color: AppColors.negro3,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        ...opciones.map((o) {
          final sel = _duracionHoras == o.$1 && !_esTodoDia;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _duracionHoras = o.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.verde.withOpacity(0.12) : AppColors.negro2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? AppColors.verde : AppColors.borde, width: sel ? 1.5 : 1),
              ),
              child: Column(children: [
                Text(o.$2, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: sel ? AppColors.verde : Colors.white)),
                Text(o.$3, style: const TextStyle(fontSize: 8, color: AppColors.texto2)),
              ]),
            ),
          ));
        }),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _duracionHoras = 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _esTodoDia ? AppColors.verde.withOpacity(0.12) : AppColors.negro2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _esTodoDia ? AppColors.verde : AppColors.borde, width: _esTodoDia ? 1.5 : 1),
            ),
            child: Column(children: [
              Icon(Icons.wb_sunny_outlined,
                color: _esTodoDia ? AppColors.verde : AppColors.texto2, size: 13),
              const SizedBox(height: 2),
              Text('Todo día', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _esTodoDia ? AppColors.verde : Colors.white)),
              Text('16h', style: const TextStyle(fontSize: 8, color: AppColors.texto2)),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ],
    ));
    if (_canchas.isEmpty) return const Center(
      child: Text('Sin canchas configuradas para este día',
          style: TextStyle(color: AppColors.texto2)));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _canchas.length,
        itemBuilder: (_, i) => _buildCanchaCard(_canchas[i]),
      ),
    );
  }

  Widget _buildCanchaCard(Map<String, dynamic> cancha) {
    final slots       = (cancha['slots'] as List?) ?? [];
    final nombre      = cancha['cancha_nombre'] ?? '';
    final precioBase  = cancha['precio_hora']?.toDouble() ?? 0.0;
    final precioDia   = cancha['precio_dia']?.toDouble();
    final precioNoche = cancha['precio_noche']?.toDouble();
    final todoDia     = _todoDiaDisponible(slots);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header cancha ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.sports_soccer, color: AppColors.verde, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: const TextStyle(
                color: AppColors.texto, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Row(children: [
                if (precioDia != null)
                  Text('☀️ S/.${precioDia.toStringAsFixed(0)}/h',
                      style: const TextStyle(color: AppColors.texto2, fontSize: 11)),
                if (precioDia != null && precioNoche != null) const SizedBox(width: 8),
                if (precioNoche != null)
                  Text('🌙 S/.${precioNoche.toStringAsFixed(0)}/h',
                      style: const TextStyle(color: AppColors.texto2, fontSize: 11)),
                if (precioDia == null && precioNoche == null)
                  Text('S/.${precioBase.toStringAsFixed(0)}/h',
                      style: const TextStyle(color: AppColors.texto2, fontSize: 11)),
              ]),
            ])),
            // Botón "Reservar todo el día"
            if (_esTodoDia)
              GestureDetector(
                onTap: todoDia
                    ? () => _abrirModal(cancha, {
                        'hora_inicio': '08:00',
                        'hora_fin':    '23:59',
                        'disponible':  true,
                      })
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: todoDia
                        ? AppColors.verde.withOpacity(0.12)
                        : AppColors.rojo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: todoDia ? AppColors.verde : AppColors.rojo.withOpacity(0.4)),
                  ),
                  child: Text(
                    todoDia ? 'Reservar' : 'No disponible',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: todoDia ? AppColors.verde : AppColors.rojo)),
                ),
              ),
          ]),
        ),
        const Divider(color: AppColors.borde, height: 1),

        // ── Grid de slots 3 columnas ─────────────────────────
        Padding(
          padding: const EdgeInsets.all(10),
          child: _esTodoDia
              ? _buildTodoDiaBanner(cancha, slots, todoDia)
              : slots.isEmpty
                  ? const Text('Sin horarios para este día',
                      style: TextStyle(color: AppColors.texto2, fontSize: 13))
                  : LayoutBuilder(builder: (ctx, constraints) {
                      final slotW = (constraints.maxWidth - 12) / 3;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(slots.length, (i) {
                          final slot       = slots[i] as Map<String, dynamic>;
                          final horaInicio = slot['hora_inicio']?.toString().substring(0, 5) ?? '';
                          final disponible = _slotSeleccionable(slots, i);
                          final ocupado    = slot['disponible'] != true;
                          final tarifa     = _precioHoraEfectivo(cancha, horaInicio);
                          final precio     = tarifa * _duracionHoras;

                          return GestureDetector(
                            onTap: disponible ? () => _abrirModal(cancha, slot) : null,
                            child: Container(
                              width: slotW,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: ocupado
                                    ? AppColors.negro2
                                    : disponible
                                        ? AppColors.verde.withOpacity(0.08)
                                        : AppColors.negro2.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ocupado
                                      ? AppColors.rojo.withOpacity(0.35)
                                      : disponible
                                          ? AppColors.verde.withOpacity(0.5)
                                          : AppColors.borde.withOpacity(0.3),
                                ),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(horaInicio, style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: ocupado
                                      ? AppColors.rojo.withOpacity(0.6)
                                      : disponible
                                          ? AppColors.verde
                                          : AppColors.texto2.withOpacity(0.5),
                                  decoration: ocupado ? TextDecoration.lineThrough : null,
                                )),
                                const SizedBox(height: 2),
                                Text(
                                  ocupado ? 'Ocupado' : 'Libre',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ocupado
                                        ? AppColors.rojo.withOpacity(0.5)
                                        : AppColors.texto2,
                                  ),
                                ),
                                if (!ocupado) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'S/.${precio.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w600,
                                      color: disponible
                                          ? AppColors.verde.withOpacity(0.9)
                                          : AppColors.texto2.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                          );
                        }),
                      );
                    }),
        ),
      ]),
    );
  }

  Widget _buildTodoDiaBanner(Map<String, dynamic> cancha, List<dynamic> slots, bool disponible) {
    final tarifa = _precioHoraEfectivo(cancha, '10:00');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: disponible ? AppColors.verde.withOpacity(0.06) : AppColors.rojo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: disponible ? AppColors.verde.withOpacity(0.3) : AppColors.rojo.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          disponible ? Icons.check_circle_outline : Icons.cancel_outlined,
          color: disponible ? AppColors.verde : AppColors.rojo, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(
          disponible
              ? 'Disponible todo el día (08:00–00:00) · S/.${(tarifa * 16).toStringAsFixed(0)}'
              : 'No disponible todo el día para esta fecha.',
          style: TextStyle(
            fontSize: 12,
            color: disponible ? AppColors.verde : AppColors.rojo),
        )),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════
// MODAL DE RESERVA MANUAL
// ══════════════════════════════════════════════════════════════

class _ModalReservaManual extends StatefulWidget {
  final Map<String, dynamic> cancha;
  final Map<String, dynamic> slot;
  final DateTime fecha;
  final VoidCallback onCreada;
  final double duracionInicial;

  const _ModalReservaManual({
    required this.cancha,
    required this.slot,
    required this.fecha,
    required this.onCreada,
    this.duracionInicial = 1.0,
  });

  @override
  State<_ModalReservaManual> createState() => _ModalState();
}

class _ModalState extends State<_ModalReservaManual> {
  final _nombreCtrl = TextEditingController();
  final _celCtrl    = TextEditingController();
  final _dniCtrl    = TextEditingController();
  final _rucCtrl    = TextEditingController();
  final _rsCtrl     = TextEditingController();

  String _metodo   = 'efectivo';
  String _tipoDoc  = 'boleta';
  late double _duracion;
  bool _loading    = false;
  String? _error;

  static const _metodos = [
    {'value': 'yape',          'label': 'Yape',         'icon': '📱'},
    {'value': 'plin',          'label': 'Plin',         'icon': '💙'},
    {'value': 'transferencia', 'label': 'Transfer.',    'icon': '🏦'},
    {'value': 'efectivo',      'label': 'Efectivo',     'icon': '💵'},
  ];

  static const _duraciones = [
    (1.0,  '1h',  'Una hora'),
    (1.5,  '1½h', 'Hora y media'),
    (2.0,  '2h',  'Dos horas'),
  ];

  @override
  void initState() {
    super.initState();
    _duracion = widget.duracionInicial == 16.0 ? 1.0 : widget.duracionInicial;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _celCtrl.dispose();
    _dniCtrl.dispose(); _rucCtrl.dispose(); _rsCtrl.dispose();
    super.dispose();
  }

  String _calcHoraFin() {
    final ini   = widget.slot['hora_inicio'] as String;
    final parts = ini.split(':');
    final total = int.parse(parts[0]) * 60 + int.parse(parts[1]) + (_duracion * 60).round();
    return '${(total ~/ 60 % 24).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  double _calcPrecio() {
    final cancha     = widget.cancha;
    final horaInicio = widget.slot['hora_inicio'] as String;
    final precioDia  = cancha['precio_dia']?.toDouble();
    final precioNoche = cancha['precio_noche']?.toDouble();
    final precioBase = cancha['precio_hora']?.toDouble() ?? 0.0;
    final h = int.parse(horaInicio.split(':')[0]);
    final tarifa = (precioDia != null || precioNoche != null)
        ? ((h >= 6 && h < 18) ? (precioDia ?? precioBase) : (precioNoche ?? precioBase))
        : precioBase;
    return tarifa * _duracion;
  }

  Future<void> _confirmar() async {
    final nombre = _nombreCtrl.text.trim();
    final cel    = _celCtrl.text.trim();
    final dni    = _dniCtrl.text.trim();

    if (nombre.isEmpty) { setState(() => _error = 'Ingresa el nombre del cliente'); return; }
    if (cel.isNotEmpty && (cel.length < 9 || int.tryParse(cel) == null)) {
      setState(() => _error = 'Celular inválido (9 dígitos)'); return;
    }
    if (dni.isNotEmpty && (dni.length != 8 || int.tryParse(dni) == null)) {
      setState(() => _error = 'El DNI debe tener 8 dígitos'); return;
    }
    if (_tipoDoc == 'factura') {
      final ruc = _rucCtrl.text.trim();
      final rs  = _rsCtrl.text.trim();
      if (ruc.length != 11 || int.tryParse(ruc) == null) {
        setState(() => _error = 'El RUC debe tener 11 dígitos'); return;
      }
      if (rs.isEmpty) { setState(() => _error = 'Ingresa la razón social'); return; }
    }

    setState(() { _loading = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'cancha_id':      widget.cancha['cancha_id'],
        'fecha':          DateFormat('yyyy-MM-dd').format(widget.fecha),
        'hora_inicio':    widget.slot['hora_inicio'],
        'hora_fin':       _calcHoraFin(),
        'nombre_cliente': nombre,
        if (cel.isNotEmpty) 'celular_cliente': cel,
        if (dni.isNotEmpty) 'dni_cliente':     dni,
        'metodo_pago':    _metodo,
        'tipo_doc':       _tipoDoc,
        if (_tipoDoc == 'factura') 'ruc_factura':  _rucCtrl.text.trim(),
        if (_tipoDoc == 'factura') 'razon_social': _rsCtrl.text.trim(),
      };
      await ApiClient().dio.post('/admin/reservas/manual', data: body);
      if (mounted) {
        Navigator.pop(context);
        widget.onCreada();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Reserva manual creada y confirmada'),
          backgroundColor: AppColors.verde,
        ));
      }
    } catch (e) {
      String msg = 'Error al crear reserva';
      if (e is DioException) msg = e.response?.data?['detail']?.toString() ?? msg;
      setState(() { _error = msg; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final precio = _calcPrecio();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                20,
        left: 20, right: 20, top: 16,
      ),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),

        // Título
        Row(children: [
          const Text('RESERVA MANUAL',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.verde, letterSpacing: 0.5)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: AppColors.texto2, size: 20)),
        ]),
        const SizedBox(height: 14),

        // Info del slot
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.verde.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.verde.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.sports_soccer, color: AppColors.verde, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.cancha['cancha_nombre'] ?? '',
                  style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.w700)),
              Text(
                '${DateFormat('dd-MM-yyyy').format(widget.fecha)}  ·  ${widget.slot['hora_inicio']} – ${_calcHoraFin()}',
                style: const TextStyle(color: AppColors.texto2, fontSize: 12),
              ),
            ])),
            Text('S/.${precio.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.verde, fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Selector de duración (cards estilo cliente) ──────
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('HORAS DE ALQUILER',
              style: TextStyle(fontSize: 10, color: AppColors.texto2,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 8),
        Row(children: _duraciones.map((o) {
          final sel    = _duracion == o.$1;
          final precio = _calcPrecioParaDur(o.$1);
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _duracion = o.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppColors.verde.withOpacity(0.12) : AppColors.negro3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? AppColors.verde : AppColors.borde, width: sel ? 1.5 : 1),
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
        const SizedBox(height: 16),

        // ── Datos del cliente ────────────────────────────────
        _campo('Nombre del cliente *', _nombreCtrl, TextInputType.name),
        const SizedBox(height: 10),
        _campo('Celular (9 dígitos)', _celCtrl, TextInputType.phone, maxLength: 9),
        const SizedBox(height: 10),
        _campo('DNI (8 dígitos)', _dniCtrl, TextInputType.number, maxLength: 8),
        const SizedBox(height: 14),

        // ── Tipo de comprobante ──────────────────────────────
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('COMPROBANTE',
              style: TextStyle(fontSize: 10, color: AppColors.texto2,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _chipDoc('boleta',  '🧾 Boleta'),
          const SizedBox(width: 8),
          _chipDoc('factura', '📄 Factura'),
        ]),
        if (_tipoDoc == 'factura') ...[
          const SizedBox(height: 10),
          _campo('RUC (11 dígitos) *', _rucCtrl, TextInputType.number, maxLength: 11),
          const SizedBox(height: 10),
          _campo('Razón Social *', _rsCtrl, TextInputType.text),
        ],
        const SizedBox(height: 14),

        // ── Método de pago ───────────────────────────────────
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('MÉTODO DE PAGO',
              style: TextStyle(fontSize: 10, color: AppColors.texto2,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 8),
        Row(children: _metodos.map((m) {
          final sel = _metodo == m['value'];
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _metodo = m['value']!),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppColors.verde.withOpacity(0.12) : AppColors.negro3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? AppColors.verde : AppColors.borde, width: sel ? 1.5 : 1),
              ),
              child: Column(children: [
                Text(m['icon']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 3),
                Text(m['label']!, style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: sel ? AppColors.verde : AppColors.texto2)),
              ]),
            ),
          ));
        }).toList()),
        const SizedBox(height: 16),

        // ── Error ────────────────────────────────────────────
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.rojo.withOpacity(0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],

        // ── Botón confirmar ──────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde,
              foregroundColor: AppColors.negro,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('💰 Confirmar Reserva',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ])),
    );
  }

  double _calcPrecioParaDur(double horas) {
    final cancha     = widget.cancha;
    final horaInicio = widget.slot['hora_inicio'] as String;
    final precioDia  = cancha['precio_dia']?.toDouble();
    final precioNoche = cancha['precio_noche']?.toDouble();
    final precioBase = cancha['precio_hora']?.toDouble() ?? 0.0;
    final h = int.parse(horaInicio.split(':')[0]);
    final tarifa = (precioDia != null || precioNoche != null)
        ? ((h >= 6 && h < 18) ? (precioDia ?? precioBase) : (precioNoche ?? precioBase))
        : precioBase;
    return tarifa * horas;
  }

  Widget _campo(String label, TextEditingController ctrl, TextInputType tipo, {int? maxLength}) =>
    TextField(
      controller: ctrl,
      keyboardType: tipo,
      maxLength: maxLength,
      style: const TextStyle(color: AppColors.texto),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.texto2, fontSize: 13),
        counterText: '',
        filled: true,
        fillColor: AppColors.negro,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borde)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borde)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.verde)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

  Widget _chipDoc(String value, String label) {
    final sel = _tipoDoc == value;
    return GestureDetector(
      onTap: () => setState(() => _tipoDoc = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.verde.withOpacity(0.12) : AppColors.negro3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.verde : AppColors.borde),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? AppColors.verde : AppColors.texto2,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
          fontSize: 13,
        )),
      ),
    );
  }
}
