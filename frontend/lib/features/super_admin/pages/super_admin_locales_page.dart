import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_local_form_page.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_canchas_page.dart';

class SuperAdminLocalesPage extends StatefulWidget {
  const SuperAdminLocalesPage({super.key});
  @override
  State<SuperAdminLocalesPage> createState() => _State();
}

class _State extends State<SuperAdminLocalesPage> {
  List<dynamic> _locales = [];
  bool _loading = true;
  String? _error;
  int _page = 0;

  static const double _overhead   = 250.0;
  static const double _cardHeight = 110.0;

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
      final res = await ApiClient().dio.get('/super-admin/locales');
      setState(() { _locales = res.data as List? ?? []; _loading = false; });
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ?? e.message ?? 'Sin respuesta';
      setState(() { _error = 'Error: $msg'; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _toggleLocal(String localId, String nombre, bool activoActual) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: Text(
          activoActual ? '⚠️ Desactivar local' : '✅ Activar local',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          activoActual
              ? '¿Desactivar "$nombre"? Desaparecerá del mapa de clientes.'
              : '¿Activar "$nombre"? Aparecerá en el mapa.',
          style: const TextStyle(color: AppColors.texto2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.texto2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: activoActual ? AppColors.rojo : AppColors.verde,
              foregroundColor: AppColors.negro,
            ),
            child: Text(activoActual ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiClient().dio.patch('/super-admin/locales/$localId/toggle');
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(activoActual ? '🚫 $nombre desactivado' : '✅ $nombre activado'),
          backgroundColor: activoActual ? AppColors.rojo : AppColors.verde,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar el local'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    final ps    = _pageSize(context);
    final total = (_locales.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _locales.skip(page * ps).take(ps).toList();

    return Column(children: [
      // Botón Nuevo Local
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SuperAdminLocalFormPage(onLocalCreado: _cargar),
          )),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.verde),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.verde.withOpacity(0.05),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, color: AppColors.verde, size: 18),
              SizedBox(width: 8),
              Text('Nuevo Local', style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
      // Lista
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          color: AppColors.amarillo,
          child: _locales.isEmpty
              ? const Center(child: Text('No hay locales registrados', style: TextStyle(color: AppColors.texto2)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _buildCard(items[i]),
                ),
        ),
      ),
      // Paginación
      if (total > 1) _paginacion(total, page),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildCard(dynamic l) {
    final activo = l['activo'] == true;
    final numCanchas = l['num_canchas'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activo ? AppColors.verde.withOpacity(0.3) : AppColors.rojo.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: activo ? AppColors.verde.withOpacity(0.1) : AppColors.rojo.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(activo ? '📍' : '🚫', style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l['nombre'] ?? '—',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(l['direccion'] ?? '—',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Admin: ${l['admin_nombre'] ?? '—'}',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          Text('$numCanchas cancha${numCanchas != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.azul)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: activo ? AppColors.verde.withOpacity(0.1) : AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(activo ? 'ACTIVO' : 'INACTIVO',
                style: TextStyle(fontSize: 9, color: activo ? AppColors.verde : AppColors.rojo, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _toggleLocal(l['id'].toString(), l['nombre'] ?? '—', activo),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: activo ? AppColors.rojo.withOpacity(0.1) : AppColors.verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: activo ? AppColors.rojo.withOpacity(0.5) : AppColors.verde.withOpacity(0.5)),
              ),
              child: Text(activo ? 'Desactivar' : 'Activar',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: activo ? AppColors.rojo : AppColors.verde)),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SuperAdminCanchasPage(
                localId: l['id'].toString(),
                localNombre: l['nombre'] ?? '—',
              ),
            )),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.azul.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.azul.withOpacity(0.5)),
              ),
              child: const Text('Canchas', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.azul)),
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
