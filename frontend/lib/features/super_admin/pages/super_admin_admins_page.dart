import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/api/api_client.dart';

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
      setState(() { _admins = res.data; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error al cargar admins'; _loading = false; });
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

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _admins.length,
        itemBuilder: (_, i) {
          final a = _admins[i];
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
    );
  }
}
