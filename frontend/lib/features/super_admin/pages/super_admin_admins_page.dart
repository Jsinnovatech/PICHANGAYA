import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/features/super_admin/pages/super_admin_admin_form_page.dart';

class SuperAdminAdminsPage extends StatefulWidget {
  const SuperAdminAdminsPage({super.key});
  @override
  State<SuperAdminAdminsPage> createState() => _State();
}

class _State extends State<SuperAdminAdminsPage> {
  List<dynamic> _admins = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  int _page = 0;

  static const double _overhead   = 250.0;
  static const double _cardHeight = 118.0;

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get('/super-admin/admins');
      setState(() { _admins = res.data as List? ?? []; _loading = false; _page = 0; });
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ?? e.message ?? 'Sin respuesta';
      setState(() { _error = 'Error al cargar admins: $msg'; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error al cargar admins: $e'; _loading = false; });
    }
  }

  Future<void> _toggleActivo(String adminId, String nombre, bool activoActual) async {
    final accion = activoActual ? 'suspender' : 'reactivar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: Text(
          activoActual ? '⚠️ Suspender admin' : '✅ Reactivar admin',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '¿Seguro que quieres $accion a $nombre?',
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
            child: Text(activoActual ? 'Suspender' : 'Reactivar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient().dio.patch(
        '${ApiConstants.superAdminToggleAdmin}/$adminId/toggle-activo',
      );
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(activoActual ? '🚫 $nombre suspendido' : '✅ $nombre reactivado'),
          backgroundColor: activoActual ? AppColors.rojo : AppColors.verde,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar el admin'),
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
    final total = (_admins.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _admins.skip(page * ps).take(ps).toList();

    return Column(children: [
      // Botón Nuevo Admin
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SuperAdminAdminFormPage(onAdminCreado: _cargar),
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
              Text('Nuevo Admin', style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
      Expanded(child: RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: _admins.isEmpty
          ? const Center(child: Text('No hay admins registrados', style: TextStyle(color: AppColors.texto2)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final a = items[i];
          final tieneActiva  = a['tiene_suscripcion_activa'] == true;
          final adminActivo  = a['activo'] == true;
          final diasRestantes = a['dias_restantes'];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: adminActivo
                    ? (tieneActiva
                        ? AppColors.verde.withOpacity(0.3)
                        : AppColors.naranja.withOpacity(0.3))
                    : AppColors.rojo.withOpacity(0.3),
              ),
            ),
            child: Row(children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: adminActivo
                      ? (tieneActiva
                          ? AppColors.verde.withOpacity(0.1)
                          : AppColors.naranja.withOpacity(0.1))
                      : AppColors.rojo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                  adminActivo ? (tieneActiva ? '✅' : '⚠️') : '🚫',
                  style: const TextStyle(fontSize: 20),
                )),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['nombre'] ?? '—',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('+51 ${a['celular'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
                  if (tieneActiva && diasRestantes != null)
                    Text(
                      'Vence en $diasRestantes días · Plan ${a['plan_actual']?.toString().toUpperCase() ?? ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.verde),
                    ),
                  if (!tieneActiva && adminActivo)
                    const Text('Sin suscripción activa',
                        style: TextStyle(fontSize: 11, color: AppColors.naranja)),
                  if (!adminActivo)
                    const Text('Cuenta suspendida',
                        style: TextStyle(fontSize: 11, color: AppColors.rojo)),
                ]),
              ),
              // Badge estado + botón toggle
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: adminActivo
                        ? AppColors.verde.withOpacity(0.1)
                        : AppColors.rojo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    adminActivo ? 'ACTIVO' : 'SUSPENDIDO',
                    style: TextStyle(
                      fontSize: 10,
                      color: adminActivo ? AppColors.verde : AppColors.rojo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _toggleActivo(
                    a['id'].toString(),
                    a['nombre'] ?? '—',
                    adminActivo,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: adminActivo
                          ? AppColors.rojo.withOpacity(0.1)
                          : AppColors.verde.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: adminActivo
                            ? AppColors.rojo.withOpacity(0.5)
                            : AppColors.verde.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      adminActivo ? 'Suspender' : 'Reactivar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: adminActivo ? AppColors.rojo : AppColors.verde,
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          );
        },
      ),
    )),
      if (total > 1) _paginacion(total, page),
      const SizedBox(height: 8),
    ]);
  }

  Widget _paginacion(int total, int current) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0, () => setState(() => _page = current - 1)),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
      if (total > 9)
        Text('${current + 1} / $total',
            style: const TextStyle(color: AppColors.amarillo, fontSize: 14, fontWeight: FontWeight.w700)),
      _arrowBtn(Icons.arrow_forward_ios, current < total - 1, () => setState(() => _page = current + 1)),
    ],
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(icon, size: 16, color: enabled ? AppColors.amarillo : AppColors.texto2.withOpacity(0.3)),
    ),
  );

  Widget _pageNum(int i, int current) => GestureDetector(
    onTap: () => setState(() => _page = i),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: i == current ? AppColors.amarillo.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: i == current ? AppColors.amarillo : AppColors.borde),
      ),
      child: Center(child: Text('${i + 1}',
          style: TextStyle(fontSize: 12,
              color: i == current ? AppColors.amarillo : AppColors.texto2,
              fontWeight: i == current ? FontWeight.w700 : FontWeight.w400))),
    ),
  );
}
