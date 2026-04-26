import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class AdminHorariosPage extends StatefulWidget {
  const AdminHorariosPage({super.key});
  @override
  State<AdminHorariosPage> createState() => _AdminHorariosPageState();
}

class _AdminHorariosPageState extends State<AdminHorariosPage> {
  // Canchas del admin
  List<Map<String, dynamic>> _canchas = [];
  Map<String, dynamic>? _canchaSeleccionada;
  bool _loadingCanchas = true;
  String? _errorCanchas;

  // Horarios de la cancha seleccionada
  List<Map<String, dynamic>> _horarios = [];
  bool _loadingHorarios = false;
  String? _error;
  int _page = 0;

  static const double _overhead    = 260.0;
  static const double _cardHeight  = 100.0;

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
    setState(() { _loadingCanchas = true; _errorCanchas = null; });
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminCanchas);
      final lista = List<Map<String, dynamic>>.from(res.data as List);
      setState(() {
        _canchas = lista;
        _loadingCanchas = false;
        if (lista.isNotEmpty) {
          _canchaSeleccionada = lista.first;
          _cargarHorarios();
        }
      });
    } catch (_) {
      setState(() {
        _errorCanchas = 'Error al cargar canchas';
        _loadingCanchas = false;
      });
    }
  }

  Future<void> _cargarHorarios() async {
    if (_canchaSeleccionada == null) return;
    setState(() { _loadingHorarios = true; _error = null; });
    try {
      final id = _canchaSeleccionada!['id'];
      final res = await ApiClient().dio.get(
        '${ApiConstants.adminHorarios}/cancha/$id',
      );
      setState(() {
        _horarios = List<Map<String, dynamic>>.from(res.data as List);
        _page = 0;
        _loadingHorarios = false;
      });
    } catch (_) {
      setState(() { _error = 'Error al cargar horarios'; _loadingHorarios = false; });
    }
  }

  Future<void> _eliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: const Text('¿Eliminar horario?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: AppColors.texto2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: AppColors.texto2))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rojo, foregroundColor: Colors.white),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient().dio.delete('${ApiConstants.adminHorarios}/$id');
      _cargarHorarios();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al eliminar horario'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  void _abrirFormulario([Map<String, dynamic>? horario]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormHorario(
        canchas: _canchas,
        canchaInicial: _canchaSeleccionada,
        horario: horario,
        onGuardado: () { Navigator.pop(context); _cargarHorarios(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCanchas) {
      return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    }
    if (_errorCanchas != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_errorCanchas!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargarCanchas, child: const Text('Reintentar')),
      ]));
    }
    if (_canchas.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🏟️', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('No tienes canchas registradas',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Crea una cancha primero en la pestaña Canchas',
            style: TextStyle(color: AppColors.texto2, fontSize: 12)),
      ]));
    }

    final ps    = _pageSize(context);
    final total = (_horarios.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _horarios.skip(page * ps).take(ps).toList();

    return Column(children: [
      // ── Header ───────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(bottom: BorderSide(color: AppColors.borde)),
        ),
        child: Row(children: [
          const Text('🗓️ HORARIOS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.5)),
          const Spacer(),
          GestureDetector(
            onTap: _cargarHorarios,
            child: const Icon(Icons.refresh, color: AppColors.texto2, size: 20),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _abrirFormulario(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.verde.withOpacity(0.5)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: AppColors.verde, size: 14),
                SizedBox(width: 4),
                Text('Nuevo', style: TextStyle(color: AppColors.verde, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),

      // ── Selector de cancha ────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        color: AppColors.negro,
        child: Row(children: [
          const Text('Cancha:', style: TextStyle(color: AppColors.texto2, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borde),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _canchaSeleccionada?['id'] as String?,
                  dropdownColor: AppColors.negro2,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  icon: const Icon(Icons.expand_more, color: AppColors.texto2, size: 18),
                  items: _canchas.map((c) => DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Text(c['nombre'] ?? '—', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (id) {
                    final cancha = _canchas.firstWhere((c) => c['id'] == id);
                    setState(() { _canchaSeleccionada = cancha; _page = 0; });
                    _cargarHorarios();
                  },
                ),
              ),
            ),
          ),
        ]),
      ),

      // ── Contenido ────────────────────────────────────────────
      if (_loadingHorarios)
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.verde)))
      else if (_error != null)
        Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_error!, style: const TextStyle(color: AppColors.rojo)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _cargarHorarios, child: const Text('Reintentar')),
        ])))
      else if (_horarios.isEmpty)
        Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🗓️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Sin horarios',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Agrega horarios con el botón "Nuevo"',
              style: TextStyle(color: AppColors.texto2, fontSize: 12)),
        ])))
      else ...[
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarHorarios,
            color: AppColors.verde,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: items.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _cardHorario(items[i]),
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

  Widget _cardHorario(Map<String, dynamic> h) {
    final activo = h['activo'] as bool? ?? true;
    final dia    = _dias[(h['dia_semana'] as int? ?? 0).clamp(0, 6)];
    final precio = h['precio_override'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (activo ? AppColors.verde : AppColors.borde).withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          // Día
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.verde.withOpacity(0.3)),
            ),
            child: Text(dia,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.verde, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),

          // Hora
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.access_time, color: AppColors.texto2, size: 12),
              const SizedBox(width: 4),
              Text('${h['hora_inicio']} – ${h['hora_fin']}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            if (precio != null) ...[
              const SizedBox(height: 3),
              Text('S/. ${precio.toString()} (override)',
                  style: const TextStyle(color: AppColors.amarillo, fontSize: 11)),
            ],
          ])),

          // Estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (activo ? AppColors.verde : AppColors.rojo).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (activo ? AppColors.verde : AppColors.rojo).withOpacity(0.4)),
            ),
            child: Text(activo ? 'ACTIVO' : 'INACTIVO',
                style: TextStyle(fontSize: 9,
                    color: activo ? AppColors.verde : AppColors.rojo,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),

          // Acciones
          GestureDetector(
            onTap: () => _abrirFormulario(h),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.edit_outlined, color: AppColors.azul, size: 18),
            ),
          ),
          GestureDetector(
            onTap: () => _eliminar(h['id'] as String),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.delete_outline, color: AppColors.rojo, size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Formulario Create/Edit ────────────────────────────────────────────────────

class _FormHorario extends StatefulWidget {
  final List<Map<String, dynamic>> canchas;
  final Map<String, dynamic>? canchaInicial;
  final Map<String, dynamic>? horario;
  final VoidCallback onGuardado;

  const _FormHorario({
    required this.canchas,
    required this.canchaInicial,
    this.horario,
    required this.onGuardado,
  });

  @override
  State<_FormHorario> createState() => _FormHorarioState();
}

class _FormHorarioState extends State<_FormHorario> {
  final _formKey = GlobalKey<FormState>();
  late String? _canchaId;
  late int _diaSemana;
  late final TextEditingController _horaInicio;
  late final TextEditingController _horaFin;
  late final TextEditingController _precioOverride;
  late bool _activo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final h = widget.horario;
    _canchaId      = h?['cancha_id'] as String? ?? widget.canchaInicial?['id'] as String?;
    _diaSemana     = h?['dia_semana'] as int? ?? 0;
    _horaInicio    = TextEditingController(text: h?['hora_inicio'] ?? '08:00');
    _horaFin       = TextEditingController(text: h?['hora_fin'] ?? '09:00');
    _precioOverride= TextEditingController(
        text: h?['precio_override']?.toString() ?? '');
    _activo        = h?['activo'] as bool? ?? true;
  }

  @override
  void dispose() {
    _horaInicio.dispose(); _horaFin.dispose(); _precioOverride.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_canchaId == null) return;
    setState(() => _guardando = true);

    final data = {
      'cancha_id'  : _canchaId,
      'dia_semana' : _diaSemana,
      'hora_inicio': _horaInicio.text.trim(),
      'hora_fin'   : _horaFin.text.trim(),
      'activo'     : _activo,
      if (_precioOverride.text.trim().isNotEmpty)
        'precio_override': double.tryParse(_precioOverride.text.trim()),
    };

    try {
      final id = widget.horario?['id'];
      if (id != null) {
        await ApiClient().dio.patch('${ApiConstants.adminHorarios}/$id', data: data);
      } else {
        await ApiClient().dio.post('${ApiConstants.adminHorarios}/', data: data);
      }
      widget.onGuardado();
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.horario != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Título
            Row(children: [
              Text(esEdicion ? '✏️ Editar Horario' : '🗓️ Nuevo Horario',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: AppColors.texto2, size: 22),
              ),
            ]),
            const SizedBox(height: 20),

            // Selector de cancha
            const Text('CANCHA', style: TextStyle(fontSize: 9, color: AppColors.texto2,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.negro,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _canchaId,
                  dropdownColor: AppColors.negro2,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.expand_more, color: AppColors.texto2, size: 18),
                  items: widget.canchas.map((c) => DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Text(c['nombre'] ?? '—'),
                  )).toList(),
                  onChanged: esEdicion ? null : (v) => setState(() => _canchaId = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Día de semana
            const Text('DÍA DE SEMANA', style: TextStyle(fontSize: 9, color: AppColors.texto2,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) => GestureDetector(
                onTap: () => setState(() => _diaSemana = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _diaSemana == i ? AppColors.verde.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _diaSemana == i ? AppColors.verde : AppColors.borde),
                  ),
                  child: Text(_dias[i], style: TextStyle(
                    fontSize: 12,
                    fontWeight: _diaSemana == i ? FontWeight.w700 : FontWeight.w400,
                    color: _diaSemana == i ? AppColors.verde : AppColors.texto2,
                  )),
                ),
              )),
            ),
            const SizedBox(height: 16),

            // Horas
            Row(children: [
              Expanded(child: _campo(_horaInicio, 'Hora inicio *', required: true)),
              const SizedBox(width: 12),
              Expanded(child: _campo(_horaFin, 'Hora fin *', required: true)),
            ]),
            const SizedBox(height: 12),
            _campo(_precioOverride, 'Precio override S/. (opcional)',
                tipo: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 16),

            // Toggle activo
            Row(children: [
              const Text('Activo', style: TextStyle(color: Colors.white, fontSize: 14)),
              const Spacer(),
              Switch(
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
                activeColor: AppColors.verde,
              ),
            ]),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _guardando
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(esEdicion ? 'Guardar cambios' : 'Crear horario',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {
    bool required = false,
    TextInputType tipo = TextInputType.text,
  }) =>
    TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.texto2, fontSize: 13),
        filled: true,
        fillColor: AppColors.negro,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borde)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borde)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.verde, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
}
