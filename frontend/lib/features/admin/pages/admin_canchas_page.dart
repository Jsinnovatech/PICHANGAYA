import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/shared/modals/add_cancha_modal.dart';

class AdminCanchasPage extends StatefulWidget {
  const AdminCanchasPage({super.key});
  @override
  State<AdminCanchasPage> createState() => _State();
}

class _State extends State<AdminCanchasPage> {
  List<dynamic> _canchas = [];
  bool _loading = true;
  String? _error;
  final Map<String, bool> _toggling = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get('/admin/canchas');
      setState(() { _canchas = res.data; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Error al cargar canchas'; _loading = false; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> c) async {
    final id = c['id'] as String;
    setState(() => _toggling[id] = true);
    try {
      await ApiClient().dio.patch('/admin/canchas/$id/toggle');
      await _cargar();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _toggling.remove(id));
    }
  }

  void _nuevaCancha() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AddCanchaModal(onSuccess: _cargar),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_error!, style: const TextStyle(color: AppColors.rojo)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
    ]));

    final activas = _canchas.where((c) => c['activa'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.negro,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaCancha,
        backgroundColor: AppColors.verde,
        foregroundColor: AppColors.negro,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cancha', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Stats
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.negro2,
          child: Row(children: [
            _chip('🏟️ Total', '${_canchas.length}', AppColors.azul),
            const SizedBox(width: 8),
            _chip('✅ Activas', '$activas', AppColors.verde),
            const SizedBox(width: 8),
            _chip('🔴 Inactivas', '${_canchas.length - activas}', AppColors.naranja),
            const Spacer(),
            GestureDetector(onTap: _cargar, child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
          ]),
        ),
        // Lista
        Expanded(
          child: _canchas.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🏟️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('No hay canchas registradas', style: TextStyle(color: AppColors.texto2)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _nuevaCancha, icon: const Icon(Icons.add), label: const Text('Agregar cancha')),
                ]))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  color: AppColors.verde,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: _canchas.length,
                    itemBuilder: (_, i) => _cardCancha(_canchas[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _cardCancha(Map<String, dynamic> c) {
    final activa = c['activa'] == true;
    final id = c['id'] as String;
    final toggling = _toggling[id] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activa ? AppColors.borde : AppColors.rojo.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: activa ? AppColors.verde.withOpacity(0.1) : AppColors.rojo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text('🏟️', style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['nombre'] ?? '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(c['local_nombre'] ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
            ])),
            _badgeActiva(activa),
          ]),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            _infoChip('⚽ ${c['superficie'] ?? 'N/A'}', AppColors.azul),
            const SizedBox(width: 6),
            _infoChip('👥 ${c['capacidad'] ?? 0}', AppColors.texto2),
            const SizedBox(width: 6),
            _infoChip('S/.${(c['precio_hora'] ?? 0.0).toStringAsFixed(0)}/hr', AppColors.verde),
          ]),
          if (c['descripcion'] != null && (c['descripcion'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(c['descripcion'], style: const TextStyle(fontSize: 11, color: AppColors.texto2), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: toggling ? null : () => _toggle(c),
              style: OutlinedButton.styleFrom(
                foregroundColor: activa ? AppColors.naranja : AppColors.verde,
                side: BorderSide(color: activa ? AppColors.naranja : AppColors.verde),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: toggling
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(activa ? '🔴 Desactivar' : '✅ Activar', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _badgeActiva(bool activa) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (activa ? AppColors.verde : AppColors.rojo).withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(activa ? '✅ ACTIVA' : '🔴 INACTIVA',
        style: TextStyle(fontSize: 10, color: activa ? AppColors.verde : AppColors.rojo, fontWeight: FontWeight.w700)),
  );

  Widget _infoChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _chip(String label, String val, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
    ]),
  );
}
