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
  DateTime _fecha = DateTime.now();
  bool _loading = false;
  List<dynamic> _canchas = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

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
      if (e is DioException) {
        msg = e.response?.data?['detail']?.toString() ?? msg;
      }
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
    if (picked != null) {
      setState(() => _fecha = picked);
      _cargar();
    }
  }

  void _abrirModal(Map<String, dynamic> cancha, Map<String, dynamic> slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModalReservaManual(
        cancha: cancha,
        slot: slot,
        fecha: _fecha,
        onCreada: _cargar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Selector de fecha ──────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.negro2,
        child: Row(children: [
          const Icon(Icons.calendar_today, color: AppColors.verde, size: 18),
          const SizedBox(width: 8),
          Text(
            DateFormat('EEEE d MMM yyyy', 'es').format(_fecha),
            style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: _elegirFecha,
            child: const Text('Cambiar', style: TextStyle(color: AppColors.verde)),
          ),
        ]),
      ),

      // ── Contenido ─────────────────────────────────────────
      Expanded(child: _buildBody()),
    ]);
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
      child: Text('Sin canchas configuradas para este día', style: TextStyle(color: AppColors.texto2)),
    );

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
    final slots = (cancha['slots'] as List?) ?? [];
    final nombre = cancha['cancha_nombre'] ?? '';
    final precio = cancha['precio_hora']?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header cancha
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.sports_soccer, color: AppColors.verde, size: 20),
            const SizedBox(width: 8),
            Text(nombre, style: const TextStyle(
              color: AppColors.texto, fontWeight: FontWeight.w700, fontSize: 15,
            )),
            const Spacer(),
            Text('S/.${precio.toStringAsFixed(0)}/h',
                style: const TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Divider(color: AppColors.borde, height: 1),

        // Grid de slots
        Padding(
          padding: const EdgeInsets.all(10),
          child: slots.isEmpty
            ? const Text('Sin horarios para este día',
                style: TextStyle(color: AppColors.texto2, fontSize: 13))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map<Widget>((slot) {
                  final disponible = slot['disponible'] == true;
                  return GestureDetector(
                    onTap: disponible ? () => _abrirModal(cancha, slot) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: disponible ? AppColors.verdeGlow : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: disponible ? AppColors.verde : Colors.red.withOpacity(0.4),
                        ),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '${slot['hora_inicio']} – ${slot['hora_fin']}',
                          style: TextStyle(
                            color: disponible ? AppColors.verde : Colors.red.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          disponible ? 'Libre' : 'Ocupado',
                          style: TextStyle(
                            color: disponible ? AppColors.texto2 : Colors.red.shade300,
                            fontSize: 10,
                          ),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
        ),
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
  const _ModalReservaManual({
    required this.cancha, required this.slot,
    required this.fecha, required this.onCreada,
  });
  @override
  State<_ModalReservaManual> createState() => _ModalState();
}

class _ModalState extends State<_ModalReservaManual> {
  final _nombreCtrl = TextEditingController();
  final _dniCtrl    = TextEditingController();
  final _rucCtrl    = TextEditingController();
  final _rsCtrl     = TextEditingController();

  String _metodo  = 'efectivo';
  String _tipoDoc = 'boleta';
  bool _loading   = false;
  String? _error;

  static const _metodos = [
    {'value': 'yape',     'label': 'Yape'},
    {'value': 'plin',     'label': 'Plin'},
    {'value': 'efectivo', 'label': 'Efectivo'},
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose(); _dniCtrl.dispose();
    _rucCtrl.dispose(); _rsCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final nombre = _nombreCtrl.text.trim();
    final dni    = _dniCtrl.text.trim();

    if (nombre.isEmpty) { setState(() => _error = 'Ingresa el nombre del cliente'); return; }
    if (dni.length != 8 || int.tryParse(dni) == null) {
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
        'cancha_id':       widget.cancha['cancha_id'],
        'fecha':           DateFormat('yyyy-MM-dd').format(widget.fecha),
        'hora_inicio':     widget.slot['hora_inicio'],
        'hora_fin':        widget.slot['hora_fin'],
        'nombre_cliente':  nombre,
        'dni_cliente':     dni,
        'metodo_pago':     _metodo,
        'tipo_doc':        _tipoDoc,
        if (_tipoDoc == 'factura') 'ruc_factura':  _rucCtrl.text.trim(),
        if (_tipoDoc == 'factura') 'razon_social': _rsCtrl.text.trim(),
      };
      await ApiClient().dio.post('/admin/reservas/manual', data: body);
      if (mounted) {
        Navigator.pop(context);
        widget.onCreada();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva manual creada'),
            backgroundColor: AppColors.verde,
          ),
        );
      }
    } catch (e) {
      String msg = 'Error al crear reserva';
      if (e is DioException) {
        msg = e.response?.data?['detail']?.toString() ?? msg;
      }
      setState(() { _error = msg; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final precio = widget.slot['precio']?.toDouble() ?? 0.0;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20, right: 20, top: 16,
      ),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Info del slot
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.verdeGlow,
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
                '${DateFormat('d MMM', 'es').format(widget.fecha)}  •  ${widget.slot['hora_inicio']} – ${widget.slot['hora_fin']}',
                style: const TextStyle(color: AppColors.texto2, fontSize: 12),
              ),
            ])),
            Text('S/.${precio.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.verde, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
        const SizedBox(height: 16),

        // Nombre
        _campo('Nombre del cliente', _nombreCtrl, TextInputType.name),
        const SizedBox(height: 10),

        // DNI
        _campo('DNI (8 dígitos)', _dniCtrl, TextInputType.number, maxLength: 8),
        const SizedBox(height: 14),

        // Tipo documento
        Row(children: [
          const Text('Comprobante:', style: TextStyle(color: AppColors.texto2, fontSize: 13)),
          const SizedBox(width: 12),
          _chipDoc('boleta',   'Boleta'),
          const SizedBox(width: 8),
          _chipDoc('factura',  'Factura'),
        ]),
        const SizedBox(height: 10),

        // Campos factura
        if (_tipoDoc == 'factura') ...[
          _campo('RUC (11 dígitos)', _rucCtrl, TextInputType.number, maxLength: 11),
          const SizedBox(height: 10),
          _campo('Razón Social', _rsCtrl, TextInputType.text),
          const SizedBox(height: 14),
        ],

        // Método de pago
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Método de pago:', style: TextStyle(color: AppColors.texto2, fontSize: 13)),
        ),
        const SizedBox(height: 8),
        Row(children: _metodos.map((m) {
          final sel = _metodo == m['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _metodo = m['value']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.verdeGlow : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? AppColors.verde : AppColors.borde),
                ),
                child: Text(m['label']!,
                    style: TextStyle(
                      color: sel ? AppColors.verde : AppColors.texto2,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    )),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 16),

        // Error
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),

        // Botón confirmar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirmar Reserva',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ])),
    );
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borde)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borde)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.verde)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

  Widget _chipDoc(String value, String label) {
    final sel = _tipoDoc == value;
    return GestureDetector(
      onTap: () => setState(() => _tipoDoc = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.verdeGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.verde : AppColors.borde),
        ),
        child: Text(label,
            style: TextStyle(
              color: sel ? AppColors.verde : AppColors.texto2,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
            )),
      ),
    );
  }
}
