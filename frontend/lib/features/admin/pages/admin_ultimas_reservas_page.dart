import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminUltimasReservasPage extends StatefulWidget {
  const AdminUltimasReservasPage({super.key});
  @override
  State<AdminUltimasReservasPage> createState() => _State();
}

class _State extends State<AdminUltimasReservasPage> {
  List<dynamic> _reservas = [];
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
      final res = await ApiClient().dio.get(ApiConstants.adminDashboard);
      setState(() {
        _reservas = res.data['ultimas_reservas'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Error al cargar reservas';
        _loading = false;
      });
    }
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'confirmed': return AppColors.verde;
      case 'pending':   return AppColors.amarillo;
      case 'active':    return AppColors.azul;
      case 'done':      return AppColors.texto2;
      case 'canceled':  return AppColors.rojo;
      default:          return AppColors.texto2;
    }
  }

  String _labelEstado(String? estado) {
    switch (estado) {
      case 'confirmed': return 'CONFIRMADA';
      case 'pending':   return 'PENDIENTE';
      case 'active':    return 'ACTIVA';
      case 'done':      return 'FINALIZADA';
      case 'canceled':  return 'CANCELADA';
      default:          return estado?.toUpperCase() ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]),
    );

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservas.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                const Text('Últimas Reservas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Text('${_reservas.length} registros',
                    style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _cargar,
                  child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18),
                ),
              ]),
            );
          }
          final r = _reservas[index - 1];
          final color = _colorEstado(r['estado']);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(children: [
              // Estado dot
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(r['codigo'] ?? '—',
                        style: const TextStyle(fontSize: 11, color: AppColors.texto2, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_labelEstado(r['estado']),
                          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(r['cliente'] ?? '—',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${r['cancha'] ?? ''} · ${r['fecha'] ?? ''} · ${r['hora'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
                ],
              )),
              // Monto
              Text('S/.${r['monto']?.toString() ?? '0'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.verde)),
            ]),
          );
        },
      ),
    );
  }
}
