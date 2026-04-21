import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminCanchasPage extends StatefulWidget {
  final String localId;
  final String localNombre;
  const SuperAdminCanchasPage({super.key, required this.localId, required this.localNombre});

  @override
  State<SuperAdminCanchasPage> createState() => _State();
}

class _State extends State<SuperAdminCanchasPage> {
  List<dynamic> _canchas = [];
  bool _loading = true;
  String? _error;
  int _page = 0;

  static const double _overhead   = 240.0;
  static const double _cardHeight = 90.0;

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
    setState(() { _loading = true; _error = null; _page = 0; });
    try {
      final res = await ApiClient().dio.get('/super-admin/locales/${widget.localId}/canchas');
      setState(() { _canchas = res.data as List? ?? []; _loading = false; });
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ?? e.message ?? 'Sin respuesta';
      setState(() { _error = 'Error: $msg'; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _toggleCancha(String canchaId, String nombre, bool activaActual) async {
    try {
      await ApiClient().dio.patch('/super-admin/canchas/$canchaId/toggle');
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(activaActual ? '🚫 $nombre desactivada' : '✅ $nombre activada'),
          backgroundColor: activaActual ? AppColors.rojo : AppColors.verde,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar la cancha'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  void _mostrarFormCancha() {
    final _nomCtrl   = TextEditingController();
    final _descCtrl  = TextEditingController();
    final _precCtrl  = TextEditingController();
    final _capCtrl   = TextEditingController(text: '10');
    final _formKey   = GlobalKey<FormState>();
    bool saving = false;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Nueva Cancha', style: TextStyle(color: AppColors.texto, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _modalCampo(_nomCtrl, 'Nombre de la cancha', 'Ej: Cancha A',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 12),
              _modalCampo(_descCtrl, 'Descripción (opcional)', 'Ej: Grass sintético 11 vs 11'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _modalCampo(_precCtrl, 'Precio/hora (S/)', 'Ej: 80',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (double.tryParse(v.trim()) == null) return 'Número inválido';
                      return null;
                    })),
                const SizedBox(width: 12),
                Expanded(child: _modalCampo(_capCtrl, 'Capacidad', 'Ej: 22',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (int.tryParse(v.trim()) == null) return 'Número inválido';
                      return null;
                    })),
              ]),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.rojo, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setModal(() { saving = true; error = null; });
                    try {
                      await ApiClient().dio.post(
                        '/super-admin/locales/${widget.localId}/canchas',
                        data: {
                          'nombre':      _nomCtrl.text.trim(),
                          'descripcion': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                          'precio_hora': double.parse(_precCtrl.text.trim()),
                          'capacidad':   int.parse(_capCtrl.text.trim()),
                          'activo':      true,
                        },
                      );
                      Navigator.pop(ctx);
                      _cargar();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('✅ Cancha creada'),
                          backgroundColor: AppColors.verde,
                        ));
                      }
                    } on DioException catch (e) {
                      final msg = e.response?.data?['detail']?.toString() ?? 'Error';
                      setModal(() { error = msg; saving = false; });
                    } catch (e) {
                      setModal(() { error = e.toString(); saving = false; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verde,
                    foregroundColor: AppColors.negro,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                      : const Text('Guardar Cancha', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _modalCampo(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.texto, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppColors.texto2, fontSize: 13),
          hintStyle: TextStyle(color: AppColors.texto2.withOpacity(0.5), fontSize: 12),
          filled: true,
          fillColor: AppColors.negro3,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borde)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borde)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.verde, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.rojo)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.rojo, width: 1.5)),
        ),
        validator: validator,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        backgroundColor: AppColors.negro2,
        title: Text('Canchas — ${widget.localNombre}',
            style: const TextStyle(color: AppColors.texto, fontSize: 15)),
        iconTheme: const IconThemeData(color: AppColors.texto),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.verde),
            onPressed: _mostrarFormCancha,
            tooltip: 'Agregar cancha',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.amarillo))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)))
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final ps    = _pageSize(context);
    final total = (_canchas.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _canchas.skip(page * ps).take(ps).toList();

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          color: AppColors.amarillo,
          child: _canchas.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Sin canchas', style: TextStyle(color: AppColors.texto2, fontSize: 15)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _mostrarFormCancha,
                    icon: const Icon(Icons.add, color: AppColors.verde),
                    label: const Text('Agregar cancha', style: TextStyle(color: AppColors.verde)),
                  ),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _buildCard(items[i]),
                ),
        ),
      ),
      if (total > 1) _paginacion(total, page),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildCard(dynamic c) {
    final activa = c['activa'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activa ? AppColors.verde.withOpacity(0.3) : AppColors.rojo.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: activa ? AppColors.verde.withOpacity(0.1) : AppColors.rojo.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(activa ? '⚽' : '🚫', style: const TextStyle(fontSize: 16))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['nombre'] ?? '—',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('S/ ${c['precio_hora']} / hora · ${c['capacidad']} jugadores',
              style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          if (c['descripcion'] != null && c['descripcion'].toString().isNotEmpty)
            Text(c['descripcion'], style: const TextStyle(fontSize: 11, color: AppColors.texto2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: activa ? AppColors.verde.withOpacity(0.1) : AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(activa ? 'ACTIVA' : 'INACTIVA',
                style: TextStyle(fontSize: 9, color: activa ? AppColors.verde : AppColors.rojo, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _toggleCancha(c['id'].toString(), c['nombre'] ?? '—', activa),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: activa ? AppColors.rojo.withOpacity(0.1) : AppColors.verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: activa ? AppColors.rojo.withOpacity(0.5) : AppColors.verde.withOpacity(0.5)),
              ),
              child: Text(activa ? 'Desactivar' : 'Activar',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: activa ? AppColors.rojo : AppColors.verde)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _paginacion(int total, int current) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0, () => setState(() => _page = current - 1)),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
      if (total > 9)
        Text('${current + 1} / $total',
            style: const TextStyle(color: AppColors.verde, fontSize: 14, fontWeight: FontWeight.w700)),
      _arrowBtn(Icons.arrow_forward_ios, current < total - 1, () => setState(() => _page = current + 1)),
    ],
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(icon, size: 16, color: enabled ? AppColors.verde : AppColors.texto2.withOpacity(0.3)),
    ),
  );

  Widget _pageNum(int i, int current) => GestureDetector(
    onTap: () => setState(() => _page = i),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: i == current ? AppColors.verde.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: i == current ? AppColors.verde : AppColors.borde),
      ),
      child: Center(child: Text('${i + 1}',
          style: TextStyle(fontSize: 12, color: i == current ? AppColors.verde : AppColors.texto2,
              fontWeight: i == current ? FontWeight.w700 : FontWeight.w400))),
    ),
  );
}
