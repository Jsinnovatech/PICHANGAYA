import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get('/super-admin/admins');
      setState(() {
        _admins = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar admins';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null)
      return Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _admins.length,
        itemBuilder: (_, i) {
          final a = _admins[i];
          final tieneActiva = a['tiene_suscripcion_activa'] == true;
          final diasRestantes = a['dias_restantes'];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tieneActiva
                    ? AppColors.verde.withOpacity(0.3)
                    : AppColors.naranja.withOpacity(0.3),
              ),
            ),
            child: Row(children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tieneActiva
                      ? AppColors.verde.withOpacity(0.1)
                      : AppColors.naranja.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text(
                  tieneActiva ? '✅' : '⚠️',
                  style: const TextStyle(fontSize: 20),
                )),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['nombre'] ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  Text('+51 ${a['celular'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.texto2)),
                  if (tieneActiva && diasRestantes != null)
                    Text(
                        'Vence en $diasRestantes días · Plan ${a['plan_actual']?.toString().toUpperCase() ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.verde)),
                  if (!tieneActiva)
                    const Text('Sin suscripción activa',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.naranja)),
                ],
              )),
              // Estado badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tieneActiva
                      ? AppColors.verde.withOpacity(0.1)
                      : AppColors.naranja.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(tieneActiva ? 'ACTIVO' : 'INACTIVO',
                    style: TextStyle(
                      fontSize: 10,
                      color: tieneActiva ? AppColors.verde : AppColors.naranja,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ]),
          );
        },
      ),
    );
  }
}
