import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class SuperAdminSuscripcionesPage extends StatefulWidget {
  const SuperAdminSuscripcionesPage({super.key});
  @override
  State<SuperAdminSuscripcionesPage> createState() => _State();
}

class _State extends State<SuperAdminSuscripcionesPage> {
  List<dynamic> _suscripciones = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  int _page = 0;

  static const double _overhead    = 200.0;
  static const double _cardHeight  = 280.0;

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await ApiClient().dio.get(ApiConstants.superAdminSuscripciones);
      setState(() {
        _suscripciones = res.data as List? ?? [];
        _page = 0;
        _loading = false;
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ?? e.message ?? 'Sin respuesta';
      setState(() { _error = 'Error al cargar suscripciones: $msg'; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error al cargar suscripciones: $e'; _loading = false; });
    }
  }

  Future<void> _verificar(String id, String accion, {String? motivo}) async {
    try {
      await ApiClient().dio.patch(
        '/super-admin/suscripciones/$id/verificar',
        data: {'accion': accion, if (motivo != null) 'motivo': motivo},
      );
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accion == 'aprobar'
              ? '✅ Suscripción aprobada'
              : '❌ Suscripción rechazada'),
          backgroundColor:
              accion == 'aprobar' ? AppColors.verde : AppColors.rojo,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al procesar'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  void _mostrarDialogoRechazo(String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: const Text('Motivo del rechazo',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Ej: Voucher ilegible, monto incorrecto...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.texto2)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _verificar(id, 'rechazar', motivo: ctrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null)
      return Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    final ps    = _pageSize(context);
    final total = (_suscripciones.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _suscripciones.skip(page * ps).take(ps).toList();

    if (_suscripciones.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('✅', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text('No hay suscripciones pendientes',
              style: TextStyle(color: AppColors.texto2, fontSize: 16)),
        ]),
      );
    }

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          color: AppColors.amarillo,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final s = items[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.negro2,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.amarillo.withOpacity(0.3)),
                  ),
                  child: Column(children: [
                    // Info del admin
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.amarillo.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                              child:
                                  Text('👑', style: TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['admin_nombre'] ?? '—',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                            Text('+51 ${s['admin_celular'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.texto2,
                                )),
                          ],
                        )),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.amarillo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                    s['plan']?.toString().toUpperCase() ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.amarillo,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ),
                              const SizedBox(height: 4),
                              Text('S/.${s['monto']?.toString() ?? '0'}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.verde,
                                  )),
                            ]),
                      ]),
                    ),

                    // Detalles
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        _chip(
                            '💳 ${s['metodo_pago']?.toString().toUpperCase() ?? ''}'),
                        const SizedBox(width: 8),
                        _chip('📅 ${s['created_at'] ?? ''}'),
                      ]),
                    ),

                    // Voucher
                    if (s['voucher_url'] != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: GestureDetector(
                          onTap: () => _verVoucher(s['voucher_url']),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.negro3,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borde),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                s['voucher_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('📄 Ver voucher',
                                      style:
                                          TextStyle(color: AppColors.texto2)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Botones aprobar/rechazar
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Expanded(
                            child: OutlinedButton(
                          onPressed: () => _mostrarDialogoRechazo(s['id']),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.rojo,
                            side: const BorderSide(color: AppColors.rojo),
                          ),
                          child: const Text('❌ Rechazar'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: ElevatedButton(
                          onPressed: () => _verificar(s['id'], 'aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.verde,
                            foregroundColor: AppColors.negro,
                          ),
                          child: const Text('✅ Aprobar'),
                        )),
                      ]),
                    ),
                  ]),
                );
              },
            ),
        ),
      ),
      if (total > 1) ...[
        _paginacion(total, page),
        const SizedBox(height: 8),
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
            style: const TextStyle(color: AppColors.amarillo, fontSize: 14, fontWeight: FontWeight.w700)),
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
        color: i == current ? AppColors.amarillo.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: i == current ? AppColors.amarillo : Colors.transparent),
      ),
      child: Text('${i + 1}', style: TextStyle(
        fontSize: 13,
        fontWeight: i == current ? FontWeight.w700 : FontWeight.normal,
        color: i == current ? AppColors.amarillo : AppColors.texto2,
      )),
    ),
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Icon(icon, size: 16, color: enabled ? AppColors.amarillo : AppColors.borde),
    ),
  );

  void _verVoucher(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.negro2,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.network(url, fit: BoxFit.contain),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cerrar', style: TextStyle(color: AppColors.texto2)),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.negro3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borde),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
      );
}
