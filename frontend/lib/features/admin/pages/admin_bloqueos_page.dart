import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminBloqueosPage extends StatefulWidget {
  const AdminBloqueosPage({super.key});
  @override
  State<AdminBloqueosPage> createState() => _AdminBloqueosPageState();
}

class _AdminBloqueosPageState extends State<AdminBloqueosPage> {
  List<dynamic> _canchas   = [];
  List<dynamic> _bloqueos  = [];
  bool _loading            = true;
  String? _error;

  // Filtros
  String? _canchaFiltroId;
  DateTime? _fechaFiltro;

  // Paginación
  int _page = 0;
  static const double _overhead   = 290.0;
  static const double _cardHeight = 110.0;

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

  @override
  void initState() {
    super.initState();
    _cargarCanchas();
  }

  Future<void> _cargarCanchas() async {
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminCanchas);
      setState(() { _canchas = res.data; });
    } catch (_) {}
    await _cargarBloqueos();
  }

  Future<void> _cargarBloqueos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{};
      if (_canchaFiltroId != null) params['cancha_id'] = _canchaFiltroId;
      if (_fechaFiltro != null) params['fecha'] = DateFormat('yyyy-MM-dd').format(_fechaFiltro!);

      final res = await ApiClient().dio.get(ApiConstants.adminBloqueos, queryParameters: params);
      setState(() {
        _bloqueos = res.data;
        _page     = 0;
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar bloqueos'; _loading = false; });
    }
  }

  Future<void> _eliminarBloqueo(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: const Text('¿Eliminar bloqueo?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('El horario quedará disponible nuevamente.', style: TextStyle(color: AppColors.texto2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.texto2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient().dio.delete('${ApiConstants.adminBloqueos}/$id');
      _cargarBloqueos();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Bloqueo eliminado'),
        backgroundColor: AppColors.verde,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error al eliminar bloqueo'),
        backgroundColor: AppColors.rojo,
      ));
    }
  }

  Future<void> _mostrarFormularioNuevo() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioBloqueo(
        canchas: _canchas,
        onCreado: _cargarBloqueos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Filtros ────────────────────────────────────────────────
      _buildFiltros(),

      // ── Lista ──────────────────────────────────────────────────
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.verde))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: AppColors.rojo)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _cargarBloqueos, child: const Text('Reintentar')),
                ]))
              : _bloqueos.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('🔓', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      const Text('No hay bloqueos activos',
                          style: TextStyle(color: AppColors.texto2, fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text('Bloquea horarios por mantenimiento o eventos',
                          style: TextStyle(color: AppColors.texto2, fontSize: 12)),
                    ]))
                  : _buildLista(context)),

      // ── FAB nuevo bloqueo ──────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _mostrarFormularioNuevo,
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Nuevo bloqueo de horario', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.naranja,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildFiltros() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    color: AppColors.negro2,
    child: Row(children: [
      // Selector de cancha
      Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
        value: _canchaFiltroId,
        hint: const Text('Todas las canchas', style: TextStyle(color: AppColors.texto2, fontSize: 12)),
        dropdownColor: AppColors.negro3,
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas', style: TextStyle(color: AppColors.texto2, fontSize: 12))),
          ..._canchas.map((c) => DropdownMenuItem(
            value: c['id'].toString(),
            child: Text(c['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          )),
        ],
        onChanged: (v) { setState(() { _canchaFiltroId = v; _page = 0; }); _cargarBloqueos(); },
      ))),
      const SizedBox(width: 8),
      // Selector de fecha
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _fechaFiltro ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 90)),
            builder: (_, child) => Theme(
              data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.verde)),
              child: child!,
            ),
          );
          if (picked != null) { setState(() { _fechaFiltro = picked; _page = 0; }); _cargarBloqueos(); }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _fechaFiltro != null ? AppColors.verde.withOpacity(0.12) : AppColors.negro3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _fechaFiltro != null ? AppColors.verde : AppColors.borde),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today, size: 14, color: _fechaFiltro != null ? AppColors.verde : AppColors.texto2),
            const SizedBox(width: 6),
            Text(
              _fechaFiltro != null ? DateFormat('dd/MM').format(_fechaFiltro!) : 'Fecha',
              style: TextStyle(fontSize: 12, color: _fechaFiltro != null ? AppColors.verde : AppColors.texto2),
            ),
          ]),
        ),
      ),
      if (_fechaFiltro != null) ...[
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () { setState(() { _fechaFiltro = null; _page = 0; }); _cargarBloqueos(); },
          child: const Icon(Icons.close, color: AppColors.texto2, size: 16),
        ),
      ],
      const SizedBox(width: 8),
      GestureDetector(onTap: _cargarBloqueos,
          child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
    ]),
  );

  Widget _buildLista(BuildContext context) {
    final ps    = _pageSize(context);
    final total = (_bloqueos.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _bloqueos.skip(page * ps).take(ps).toList();

    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          itemCount: items.length,
          itemBuilder: (_, i) => _cardBloqueo(items[i]),
        ),
      ),
      if (total > 1) ...[_paginacion(total, page), const SizedBox(height: 4)],
    ]);
  }

  Widget _cardBloqueo(Map<String, dynamic> b) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.negro2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.naranja.withOpacity(0.4)),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.naranja.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.block, color: AppColors.naranja, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b['cancha_nombre'] ?? '—',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 3),
        Row(children: [
          const Icon(Icons.calendar_today, size: 11, color: AppColors.texto2),
          const SizedBox(width: 4),
          Text(b['fecha'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          const SizedBox(width: 10),
          const Icon(Icons.access_time, size: 11, color: AppColors.texto2),
          const SizedBox(width: 4),
          Text('${b['hora_inicio']} – ${b['hora_fin']}',
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        if (b['motivo'] != null && b['motivo'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(b['motivo'], style: const TextStyle(fontSize: 11, color: AppColors.texto2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ])),
      GestureDetector(
        onTap: () => _eliminarBloqueo(b['id'].toString()),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.rojo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.rojo.withOpacity(0.3)),
          ),
          child: const Icon(Icons.delete_outline, color: AppColors.rojo, size: 18),
        ),
      ),
    ]),
  );

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0, () => setState(() => _page = current - 1)),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
      if (total > 9) Text('${current + 1} / $total',
          style: const TextStyle(color: AppColors.verde, fontSize: 14, fontWeight: FontWeight.w700)),
      _arrowBtn(Icons.arrow_forward_ios, current < total - 1, () => setState(() => _page = current + 1)),
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
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(icon, size: 16, color: enabled ? AppColors.verde : AppColors.borde)),
  );
}

// ══════════════════════════════════════════════════════════════
// FORMULARIO NUEVO BLOQUEO
// ══════════════════════════════════════════════════════════════

class _FormularioBloqueo extends StatefulWidget {
  final List<dynamic> canchas;
  final VoidCallback onCreado;
  const _FormularioBloqueo({required this.canchas, required this.onCreado});
  @override
  State<_FormularioBloqueo> createState() => _FormularioBloqueoState();
}

class _FormularioBloqueoState extends State<_FormularioBloqueo> {
  String? _canchaId;
  DateTime _fecha          = DateTime.now();
  String _horaInicio       = '08:00';
  String _horaFin          = '10:00';
  final _motivoCtrl        = TextEditingController();
  bool _loading            = false;
  String? _error;

  // Slots de 1 hora de 07:00 a 00:00
  static final List<String> _horas = List.generate(17, (i) {
    final h = i + 7;
    return h == 24 ? '00:00' : '${h.toString().padLeft(2, '0')}:00';
  });

  @override
  void dispose() { _motivoCtrl.dispose(); super.dispose(); }

  Future<void> _crear() async {
    if (_canchaId == null) { setState(() { _error = 'Selecciona una cancha'; }); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient().dio.post(ApiConstants.adminBloqueos, data: {
        'cancha_id':   _canchaId,
        'fecha':       DateFormat('yyyy-MM-dd').format(_fecha),
        'hora_inicio': _horaInicio,
        'hora_fin':    _horaFin,
        'motivo':      _motivoCtrl.text.trim().isEmpty ? null : _motivoCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreado();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🔒 Horario bloqueado correctamente'),
          backgroundColor: AppColors.naranja,
        ));
      }
    } catch (e) {
      String msg = 'Error al crear bloqueo';
      try {
        final data = (e as dynamic).response?.data;
        if (data != null && data['detail'] != null) msg = data['detail'].toString();
      } catch (_) {}
      setState(() { _error = msg; _loading = false; });
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
        left: 20, right: 20, top: 16,
      ),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        Row(children: [
          const Icon(Icons.block, color: AppColors.naranja, size: 20),
          const SizedBox(width: 8),
          const Text('NUEVO BLOQUEO DE HORARIO',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.naranja)),
          const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: AppColors.texto2, size: 20)),
        ]),
        const SizedBox(height: 20),

        // Cancha
        _label('CANCHA *'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borde),
          ),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _canchaId,
            isExpanded: true,
            dropdownColor: AppColors.negro3,
            hint: const Text('Selecciona cancha', style: TextStyle(color: AppColors.texto2)),
            items: widget.canchas.map((c) => DropdownMenuItem<String>(
              value: c['id'].toString(),
              child: Text(c['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (v) => setState(() => _canchaId = v),
          )),
        ),
        const SizedBox(height: 14),

        // Fecha
        _label('FECHA *'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _fecha,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              builder: (_, child) => Theme(
                data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.verde)),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _fecha = picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.negro3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borde),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: AppColors.verde, size: 16),
              const SizedBox(width: 10),
              Text(DateFormat('EEEE d MMMM yyyy', 'es').format(_fecha),
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Horas
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('HORA INICIO *'),
            const SizedBox(height: 6),
            _selectorHora(_horaInicio, (v) => setState(() => _horaInicio = v)),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('HORA FIN *'),
            const SizedBox(height: 6),
            _selectorHora(_horaFin, (v) => setState(() => _horaFin = v)),
          ])),
        ]),
        const SizedBox(height: 14),

        // Motivo
        _label('MOTIVO (opcional)'),
        const SizedBox(height: 6),
        TextField(
          controller: _motivoCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej: Mantenimiento del césped, Evento privado...',
          ),
        ),
        const SizedBox(height: 16),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _crear,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.naranja,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('🔒 Crear Bloqueo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ])),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 10, color: AppColors.texto2,
          fontWeight: FontWeight.w700, letterSpacing: 0.5));

  Widget _selectorHora(String valor, ValueChanged<String> onChange) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.negro3,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borde),
    ),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: _horas.contains(valor) ? valor : _horas.first,
      isExpanded: true,
      dropdownColor: AppColors.negro3,
      items: _horas.map((h) => DropdownMenuItem(
        value: h,
        child: Text(h, style: const TextStyle(color: Colors.white)),
      )).toList(),
      onChanged: (v) { if (v != null) onChange(v); },
    )),
  );
}
