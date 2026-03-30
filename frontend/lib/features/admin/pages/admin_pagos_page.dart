import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminPagosPage extends StatefulWidget {
  const AdminPagosPage({super.key});
  @override
  State<AdminPagosPage> createState() => _State();
}

class _State extends State<AdminPagosPage> {
  List<dynamic> _pagos = [];
  bool _loading = true;
  String? _error;
  String _filtro = 'pendiente';
  // pendiente | verificado | rechazado | todos

  static const _filtros = [
    ('pendiente', '⏳ Pendientes'),
    ('verificado', '✅ Verificados'),
    ('rechazado', '❌ Rechazados'),
    ('todos', '📋 Todos'),
  ];

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
      final params =
          _filtro != 'todos' ? {'estado': _filtro} : <String, dynamic>{};
      final res = await ApiClient().dio.get(
            ApiConstants.adminPagos,
            queryParameters: params,
          );
      setState(() {
        _pagos = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar pagos';
        _loading = false;
      });
    }
  }

  Future<void> _verificarPago(String pagoId, String accion,
      {String? motivo}) async {
    try {
      await ApiClient().dio.patch(
        '/admin/pagos/$pagoId/verificar',
        data: {
          'accion': accion,
          if (motivo != null) 'motivo': motivo,
        },
      );
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accion == 'aprobar'
              ? '✅ Pago verificado — Reserva confirmada'
              : '❌ Pago rechazado'),
          backgroundColor:
              accion == 'aprobar' ? AppColors.verde : AppColors.rojo,
        ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al procesar'),
          backgroundColor: AppColors.rojo,
        ));
    }
  }

  void _mostrarDialogoRechazo(String pagoId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: const Text('Motivo del rechazo',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              hintText: 'Ej: Voucher ilegible, monto incorrecto...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.texto2))),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _verificarPago(pagoId, 'rechazar', motivo: ctrl.text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
              child: const Text('Rechazar')),
        ],
      ),
    );
  }

  void _verVoucher(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.negro2,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Error al cargar imagen',
                        style: TextStyle(color: AppColors.texto2)))),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar',
                  style: TextStyle(color: AppColors.texto2))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Filtros ─────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: AppColors.negro2,
        child: Row(children: [
          Expanded(
              child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: _filtros
                    .map((f) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _filtro = f.$1;
                            });
                            _cargar();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _filtro == f.$1
                                  ? AppColors.verde.withOpacity(0.15)
                                  : AppColors.negro3,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _filtro == f.$1
                                      ? AppColors.verde
                                      : AppColors.borde),
                            ),
                            child: Text(f.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _filtro == f.$1
                                      ? AppColors.verde
                                      : AppColors.texto2,
                                  fontWeight: _filtro == f.$1
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                )),
                          ),
                        ))
                    .toList()),
          )),
          GestureDetector(
              onTap: _cargar,
              child:
                  const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
        ]),
      ),

      // ── Contenido ───────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.verde))
            : _error != null
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text(_error!,
                            style: const TextStyle(color: AppColors.rojo)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar')),
                      ]))
                : _pagos.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Text('💳', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text(
                                _filtro == 'pendiente'
                                    ? 'No hay pagos pendientes'
                                    : 'No hay pagos en esta categoría',
                                style:
                                    const TextStyle(color: AppColors.texto2)),
                          ]))
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        color: AppColors.verde,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _pagos.length,
                          itemBuilder: (_, i) => _cardPago(_pagos[i]),
                        ),
                      ),
      ),
    ]);
  }

  Widget _cardPago(Map<String, dynamic> p) {
    final estado = p['estado'] ?? '';
    final esPendiente = estado == 'pendiente';
    final tieneVoucher = p['voucher_url'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorEstado(estado).withOpacity(0.3)),
      ),
      child: Column(children: [
        // ── Info principal ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar método
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _colorMetodo(p['metodo'] ?? '').withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(_iconoMetodo(p['metodo'] ?? ''),
                      style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p['reserva_codigo'] ?? '—',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.texto2,
                          fontWeight: FontWeight.w600)),
                  Text(p['cliente_nombre'] ?? '—',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text('+51 ${p['cliente_celular'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.texto2)),
                  Text(p['fecha'] ?? '',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.texto2)),
                ])),
            // Monto + estado
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('S/.${p['monto']?.toString() ?? '0'}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.verde)),
              _badgeEstado(estado),
            ]),
          ]),
        ),

        // ── Voucher ──────────────────────────────────────────
        if (tieneVoucher) ...[
          const Divider(color: AppColors.borde, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () => _verVoucher(p['voucher_url']),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.negro3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borde),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(children: [
                    Image.network(
                      p['voucher_url'],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text('📄 Ver voucher',
                              style: TextStyle(color: AppColors.texto2))),
                    ),
                    // Overlay "Ver voucher"
                    Positioned.fill(
                        child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                      child: const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('👁 Toca para ver completo',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    )),
                  ]),
                ),
              ),
            ),
          ),
        ] else if (esPendiente) ...[
          const Divider(color: AppColors.borde, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.amarillo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amarillo.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.hourglass_empty,
                    color: AppColors.amarillo, size: 16),
                SizedBox(width: 8),
                Text('Esperando que el cliente suba el voucher',
                    style: TextStyle(fontSize: 12, color: AppColors.amarillo)),
              ]),
            ),
          ),
        ],

        // ── Botones aprobar/rechazar (solo si tiene voucher y está pendiente) ──
        if (esPendiente && tieneVoucher) ...[
          const Divider(color: AppColors.borde, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => _mostrarDialogoRechazo(p['id']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rojo,
                        side: const BorderSide(color: AppColors.rojo),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('❌ Rechazar'))),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () => _verificarPago(p['id'], 'aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verde,
                        foregroundColor: AppColors.negro,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('✅ Aprobar'))),
            ]),
          ),
        ] else
          const SizedBox(height: 4),
      ]),
    );
  }

  Widget _badgeEstado(String estado) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _colorEstado(estado).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(_labelEstado(estado),
            style: TextStyle(
                fontSize: 9,
                color: _colorEstado(estado),
                fontWeight: FontWeight.w700)),
      );

  Color _colorEstado(String e) {
    switch (e) {
      case 'verificado':
        return AppColors.verde;
      case 'pendiente':
        return AppColors.amarillo;
      case 'rechazado':
        return AppColors.rojo;
      default:
        return AppColors.texto2;
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'verificado':
        return '✅ VERIFICADO';
      case 'pendiente':
        return '⏳ PENDIENTE';
      case 'rechazado':
        return '❌ RECHAZADO';
      default:
        return e.toUpperCase();
    }
  }

  Color _colorMetodo(String m) {
    switch (m) {
      case 'yape':
        return const Color(0xFF7B2FBE);
      case 'plin':
        return AppColors.azul;
      case 'transferencia':
        return AppColors.verde;
      default:
        return AppColors.texto2;
    }
  }

  String _iconoMetodo(String m) {
    switch (m) {
      case 'yape':
        return '📱';
      case 'plin':
        return '💙';
      case 'transferencia':
        return '🏦';
      case 'efectivo':
        return '💵';
      default:
        return '💳';
    }
  }
}
