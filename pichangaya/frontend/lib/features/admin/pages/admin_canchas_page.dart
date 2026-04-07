import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class AdminCanchasPage extends StatefulWidget {
  const AdminCanchasPage({super.key});
  @override
  State<AdminCanchasPage> createState() => _AdminCanchasPageState();
}

class _AdminCanchasPageState extends State<AdminCanchasPage> {
  List<Map<String, dynamic>> _canchas = [];
  String _localNombre = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      // ✅ Solo canchas del local del admin logueado
      final res = await ApiClient().dio.get('/admin/mis-canchas');
      final lista = (res.data as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _canchas = lista;
        _localNombre = lista.isNotEmpty
            ? lista[0]['local_nombre']?.toString() ?? '' : '';
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar canchas'; _loading = false; });
    }
  }

  Future<void> _toggleCancha(Map<String, dynamic> cancha) async {
    try {
      await ApiClient().dio.patch('/admin/canchas/${cancha['id']}/toggle');
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(cancha['activa'] == true
              ? '🔒 Cancha desactivada' : '✅ Cancha activada'),
          backgroundColor: cancha['activa'] == true
              ? AppColors.naranja : AppColors.verde,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar cancha'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  Future<void> _confirmarToggle(Map<String, dynamic> c) async {
    final activa = c['activa'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: Text(activa ? '¿Desactivar cancha?' : '¿Activar cancha?',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
            activa
                ? 'No se podrán hacer nuevas reservas en ${c['nombre']}'
                : '${c['nombre']} volverá a estar disponible',
            style: const TextStyle(color: AppColors.texto2, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.texto2))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: activa ? AppColors.naranja : AppColors.verde,
                  foregroundColor: AppColors.negro),
              child: Text(activa ? 'Desactivar' : 'Activar')),
        ],
      ),
    );
    if (ok == true) _toggleCancha(c);
  }

  void _mostrarModalNuevaCancha() {
    // Obtener local_id de las canchas existentes
    final localId = _canchas.isNotEmpty
        ? _canchas[0]['local_id']?.toString() : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ModalNuevaCancha(
        localId: localId,
        localNombre: _localNombre,
        onGuardado: _cargar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        // ── Header con nombre del local ────────────────────
        if (_localNombre.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: AppColors.negro2,
            child: Row(children: [
              const Icon(Icons.location_on, color: AppColors.verde, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(_localNombre,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white,
                      fontWeight: FontWeight.w600))),
              Text('${_canchas.length} canchas',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.texto2)),
              const SizedBox(width: 8),
              GestureDetector(onTap: _cargar,
                  child: const Icon(Icons.refresh,
                      color: AppColors.texto2, size: 16)),
            ]),
          ),

        // ── Lista canchas ───────────────────────────────────
        Expanded(
          child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.verde))
            : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: AppColors.rojo)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _cargar,
                      child: const Text('Reintentar')),
                ]))
              : _canchas.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('🏟️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('No tienes canchas registradas',
                        style: TextStyle(color: AppColors.texto2, fontSize: 15)),
                    const SizedBox(height: 8),
                    const Text(
                        'Toca el botón + para agregar\ntu primera cancha',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.texto2, fontSize: 12)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _cargar,
                    color: AppColors.verde,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      itemCount: _canchas.length,
                      itemBuilder: (_, i) => _cardCancha(_canchas[i]),
                    ),
                  ),
        ),
      ]),

      // ── FAB Nueva Cancha ────────────────────────────────
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          onPressed: _mostrarModalNuevaCancha,
          backgroundColor: AppColors.verde,
          foregroundColor: AppColors.negro,
          icon: const Icon(Icons.add),
          label: const Text('Nueva Cancha',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _cardCancha(Map<String, dynamic> c) {
    final activa = c['activa'] == true;
    final precioRaw = c['precio_hora'] ?? 0;
    final precio = precioRaw is num
        ? precioRaw.toDouble()
        : double.tryParse(precioRaw.toString()) ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: activa
                ? AppColors.verde.withOpacity(0.3)
                : AppColors.naranja.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Icono
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: activa
                  ? AppColors.verde.withOpacity(0.1)
                  : AppColors.naranja.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.sports_soccer,
                color: activa ? AppColors.verde : AppColors.naranja,
                size: 24),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c['nombre']?.toString() ?? '—',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: activa
                        ? AppColors.verde.withOpacity(0.1)
                        : AppColors.naranja.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(activa ? 'ACTIVA' : 'INACTIVA',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: activa
                            ? AppColors.verde : AppColors.naranja)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              _chip('${c['capacidad'] ?? 0} jugadores', AppColors.texto2),
              const SizedBox(width: 6),
              _chip(c['superficie']?.toString() ?? 'Gras Sintético',
                  AppColors.texto2),
            ]),
          ])),
          const SizedBox(width: 10),

          // Precio + toggle
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('S/.${precio.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: AppColors.verde)),
            const Text('/hora',
                style: TextStyle(fontSize: 9, color: AppColors.texto2)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _confirmarToggle(c),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: activa
                        ? AppColors.naranja.withOpacity(0.1)
                        : AppColors.verde.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: activa
                            ? AppColors.naranja : AppColors.verde)),
                child: Text(activa ? '🔒 Desactivar' : '✅ Activar',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: activa
                            ? AppColors.naranja : AppColors.verde)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(t, style: TextStyle(fontSize: 9, color: c)));
}

// ══════════════════════════════════════════════════════════════
// MODAL NUEVA CANCHA — usa el local_id del admin
// ══════════════════════════════════════════════════════════════
class _ModalNuevaCancha extends StatefulWidget {
  final String? localId;
  final String localNombre;
  final VoidCallback onGuardado;
  const _ModalNuevaCancha({
    required this.localId,
    required this.localNombre,
    required this.onGuardado,
  });
  @override
  State<_ModalNuevaCancha> createState() => _ModalNuevaCanchaState();
}

class _ModalNuevaCanchaState extends State<_ModalNuevaCancha> {
  final _nombreCtrl    = TextEditingController();
  final _capacidadCtrl = TextEditingController(text: '10');
  final _precioCtrl    = TextEditingController();
  String _superficie   = 'Gras Sintético';
  bool _loading = false;
  String? _error;

  static const _superficies = [
    'Gras Sintético', 'Piso Madera', 'Cemento', 'Tierra',
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _capacidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el nombre'); return;
    }
    if (widget.localId == null) {
      setState(() => _error = 'No tienes un local asignado aún'); return;
    }
    if (_precioCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el precio por hora'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient().dio.post('/admin/canchas', data: {
        'local_id':    widget.localId,
        'nombre':      _nombreCtrl.text.trim(),
        'capacidad':   int.tryParse(_capacidadCtrl.text) ?? 10,
        'precio_hora': double.tryParse(_precioCtrl.text) ?? 0,
        'superficie':  _superficie,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onGuardado();
      }
    } catch (_) {
      setState(() {
        _error = 'Error al crear cancha. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20, right: 20, top: 16),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.borde,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          const Text('NUEVA CANCHA', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800,
              color: AppColors.verde)),
          const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close,
                  color: AppColors.texto2, size: 20)),
        ]),
        const SizedBox(height: 4),

        // Local del admin — solo lectura
        if (widget.localNombre.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.verde.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.location_on,
                  color: AppColors.verde, size: 14),
              const SizedBox(width: 6),
              Text(widget.localNombre,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.verde,
                      fontWeight: FontWeight.w600)),
            ]),
          ),

        const SizedBox(height: 12),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.rojo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_error!,
                style: const TextStyle(
                    color: AppColors.rojo, fontSize: 13)),
          ),
          const SizedBox(height: 12),
        ],

        _label('NOMBRE DE LA CANCHA'),
        TextField(controller: _nombreCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('Ej: Cancha G')),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('CAPACIDAD'),
            TextField(controller: _capacidadCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('10')),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('PRECIO / HORA (S/.)'),
            TextField(controller: _precioCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('80')),
          ])),
        ]),
        const SizedBox(height: 12),

        _label('SUPERFICIE'),
        DropdownButtonFormField<String>(
          value: _superficie,
          dropdownColor: AppColors.negro2,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco(''),
          items: _superficies.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s,
                  style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: (v) => setState(() => _superficie = v ?? _superficie),
        ),
        const SizedBox(height: 20),

        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _guardar,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verde,
                foregroundColor: AppColors.negro,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.negro))
                : const Text('✅ Guardar Cancha',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
          )),
        const SizedBox(height: 8),
      ])),
    );
  }

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(
          fontSize: 10, color: AppColors.texto2,
          letterSpacing: 0.5, fontWeight: FontWeight.w600)));

  InputDecoration _inputDeco(String h) => InputDecoration(
    hintText: h, filled: true, fillColor: AppColors.negro3,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borde)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borde)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.verde, width: 1.5)),
  );
}
