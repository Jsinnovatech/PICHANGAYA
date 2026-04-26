import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminLocalesPage extends StatefulWidget {
  const AdminLocalesPage({super.key});
  @override
  State<AdminLocalesPage> createState() => _AdminLocalesPageState();
}

class _AdminLocalesPageState extends State<AdminLocalesPage> {
  List<Map<String, dynamic>> _locales = [];
  bool _loading = true;
  String? _error;
  int _page = 0;

  static const double _overhead    = 200.0;
  static const double _cardHeight  = 140.0;

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
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminLocales);
      setState(() {
        _locales = List<Map<String, dynamic>>.from(res.data as List);
        _page    = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar locales'; _loading = false; });
    }
  }

  Future<void> _toggleActivo(Map<String, dynamic> local) async {
    final nuevoEstado = !(local['activo'] as bool? ?? true);
    try {
      await ApiClient().dio.patch(
        '${ApiConstants.adminLocales}/${local['id']}',
        data: {'activo': nuevoEstado},
      );
      _cargar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al cambiar estado'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  void _abrirFormulario([Map<String, dynamic>? local]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormLocal(
        local: local,
        onGuardado: () { Navigator.pop(context); _cargar(); },
      ),
    );
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
    final total = (_locales.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _locales.skip(page * ps).take(ps).toList();

    return Column(children: [
      // ── Header ───────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(bottom: BorderSide(color: AppColors.borde)),
        ),
        child: Row(children: [
          const Text('📍 MIS LOCALES',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.5)),
          const Spacer(),
          if (_locales.isNotEmpty)
            Text('(${_locales.length} locales)',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _cargar,
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

      // ── Contenido ────────────────────────────────────────────
      if (_locales.isEmpty)
        const Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('📍', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('No tienes locales registrados',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Crea tu primer local con el botón "Nuevo"',
              style: TextStyle(color: AppColors.texto2, fontSize: 12)),
        ])))
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
                child: _cardLocal(items[i]),
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

  Widget _cardLocal(Map<String, dynamic> local) {
    final activo = local['activo'] as bool? ?? true;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (activo ? AppColors.verde : AppColors.rojo).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [BoxShadow(
          color: (activo ? AppColors.verde : AppColors.rojo).withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: nombre + badge
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(
              child: Text(local['nombre'] ?? '—',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _badge(activo),
          ]),
        ),

        const SizedBox(height: 8),
        const Divider(color: AppColors.borde, height: 1),

        // Fila: Dirección · Teléfono
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            Expanded(child: _info(
              Icons.location_on, 'DIRECCIÓN', local['direccion'] ?? '—')),
            _info(Icons.phone, 'TELÉFONO', local['telefono'] ?? '—'),
          ]),
        ),

        // Fila: Lat · Lng
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Row(children: [
            _info(Icons.gps_fixed, 'LAT', local['lat']?.toString() ?? '—'),
            const SizedBox(width: 16),
            _info(Icons.gps_not_fixed, 'LNG', local['lng']?.toString() ?? '—'),
          ]),
        ),

        // Acciones
        const SizedBox(height: 8),
        const Divider(color: AppColors.borde, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            _btnAccion(
              icon: Icons.edit_outlined,
              label: 'Editar',
              color: AppColors.azul,
              onTap: () => _abrirFormulario(local),
            ),
            const SizedBox(width: 10),
            _btnAccion(
              icon: activo ? Icons.pause_circle_outline : Icons.play_circle_outline,
              label: activo ? 'Desactivar' : 'Activar',
              color: activo ? AppColors.amarillo : AppColors.verde,
              onTap: () => _toggleActivo(local),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _info(IconData icon, String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.texto2, size: 11),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.texto2,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ],
  );

  Widget _badge(bool activo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (activo ? AppColors.verde : AppColors.rojo).withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (activo ? AppColors.verde : AppColors.rojo).withOpacity(0.4)),
    ),
    child: Text(activo ? 'ACTIVO' : 'INACTIVO',
        style: TextStyle(fontSize: 9,
            color: activo ? AppColors.verde : AppColors.rojo,
            fontWeight: FontWeight.w700)),
  );

  Widget _btnAccion({required IconData icon, required String label,
      required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

// ── Formulario Create/Edit ────────────────────────────────────────────────────

class _FormLocal extends StatefulWidget {
  final Map<String, dynamic>? local;
  final VoidCallback onGuardado;
  const _FormLocal({this.local, required this.onGuardado});

  @override
  State<_FormLocal> createState() => _FormLocalState();
}

class _FormLocalState extends State<_FormLocal> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _direccion;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _telefono;
  late final TextEditingController _descripcion;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final l = widget.local;
    _nombre     = TextEditingController(text: l?['nombre']     ?? '');
    _direccion  = TextEditingController(text: l?['direccion']  ?? '');
    _lat        = TextEditingController(text: l?['lat']?.toString() ?? '');
    _lng        = TextEditingController(text: l?['lng']?.toString() ?? '');
    _telefono   = TextEditingController(text: l?['telefono']   ?? '');
    _descripcion= TextEditingController(text: l?['descripcion']?? '');
  }

  @override
  void dispose() {
    _nombre.dispose(); _direccion.dispose(); _lat.dispose();
    _lng.dispose(); _telefono.dispose(); _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final data = {
      'nombre'     : _nombre.text.trim(),
      'direccion'  : _direccion.text.trim(),
      'lat'        : double.tryParse(_lat.text.trim()) ?? 0.0,
      'lng'        : double.tryParse(_lng.text.trim()) ?? 0.0,
      if (_telefono.text.trim().isNotEmpty)    'telefono':    _telefono.text.trim(),
      if (_descripcion.text.trim().isNotEmpty) 'descripcion': _descripcion.text.trim(),
    };

    try {
      final id = widget.local?['id'];
      if (id != null) {
        await ApiClient().dio.patch('${ApiConstants.adminLocales}/$id', data: data);
      } else {
        await ApiClient().dio.post(ApiConstants.adminLocales, data: data);
      }
      widget.onGuardado();
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.local != null;
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
              Text(esEdicion ? '✏️ Editar Local' : '📍 Nuevo Local',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: AppColors.texto2, size: 22),
              ),
            ]),
            const SizedBox(height: 20),

            _campo(_nombre, 'Nombre del local *', required: true),
            const SizedBox(height: 12),
            _campo(_direccion, 'Dirección *', required: true),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _campo(_lat, 'Latitud *', required: true, tipo: TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 12),
              Expanded(child: _campo(_lng, 'Longitud *', required: true, tipo: TextInputType.numberWithOptions(decimal: true, signed: true))),
            ]),
            const SizedBox(height: 12),
            _campo(_telefono, 'Teléfono (opcional)', tipo: TextInputType.phone),
            const SizedBox(height: 12),
            _campo(_descripcion, 'Descripción (opcional)', maxLines: 3),
            const SizedBox(height: 24),

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
                    : Text(esEdicion ? 'Guardar cambios' : 'Crear local',
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
    int maxLines = 1,
  }) =>
    TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.texto2, fontSize: 13),
        filled: true,
        fillColor: AppColors.negro,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.verde, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
}
