import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/features/admin/providers/pagos_provider.dart';

class AdminPagosPage extends ConsumerStatefulWidget {
  const AdminPagosPage({super.key});
  @override
  ConsumerState<AdminPagosPage> createState() => _State();
}

class _State extends ConsumerState<AdminPagosPage> {
  static const _filtros = [
    ('pendiente',  '⏳ Pendientes'),
    ('verificado', '✅ Verificados'),
    ('rechazado',  '❌ Rechazados'),
    ('todos',      '📋 Todos'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(adminPagosProvider.notifier).cargar());
  }

  Future<void> _verificarPago(String pagoId, String accion,
      {String? motivo}) async {
    final ok = await ref
        .read(adminPagosProvider.notifier)
        .verificarPago(pagoId, accion, motivo: motivo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (accion == 'aprobar'
              ? '✅ Pago verificado — Reserva confirmada'
              : '❌ Pago rechazado')
          : 'Error al procesar'),
      backgroundColor:
          ok ? (accion == 'aprobar' ? AppColors.verde : AppColors.rojo)
             : AppColors.rojo,
    ));
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
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
    final state = ref.watch(adminPagosProvider);

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
                          onTap: () => ref
                              .read(adminPagosProvider.notifier)
                              .cargar(filtro: f.$1),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: state.filtro == f.$1
                                  ? AppColors.verde.withOpacity(0.15)
                                  : AppColors.negro3,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: state.filtro == f.$1
                                      ? AppColors.verde
                                      : AppColors.borde),
                            ),
                            child: Text(f.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: state.filtro == f.$1
                                      ? AppColors.verde
                                      : AppColors.texto2,
                                  fontWeight: state.filtro == f.$1
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                )),
                          ),
                        ))
                    .toList()),
          )),
          GestureDetector(
              onTap: () => ref.read(adminPagosProvider.notifier).cargar(),
              child: const Icon(Icons.refresh,
                  color: AppColors.texto2, size: 18)),
        ]),
      ),

      // ── Contenido ───────────────────────────────────────────
      Expanded(
        child: state.loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.verde))
            : state.error != null
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text(state.error!,
                            style: const TextStyle(color: AppColors.rojo)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: () => ref
                                .read(adminPagosProvider.notifier)
                                .cargar(),
                            child: const Text('Reintentar')),
                      ]))
                : state.pagos.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Text('💳',
                                style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text(
                                state.filtro == 'pendiente'
                                    ? 'No hay pagos pendientes'
                                    : 'No hay pagos en esta categoría',
                                style:
                                    const TextStyle(color: AppColors.texto2)),
                          ]))
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(adminPagosProvider.notifier).cargar(),
                        color: AppColors.verde,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.pagos.length,
                          itemBuilder: (_, i) =>
                              _cardPago(state.pagos[i]),
                        ),
                      ),
      ),
    ]);
  }

  Widget _cardPago(Map<String, dynamic> p) {
    final estado      = p['estado'] ?? '';
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
        // Info principal
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _colorMetodo(p['metodo'] ?? '').withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(_iconoMetodo(p['metodo'] ?? ''),
                      style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
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

        // Voucher
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
                    Image.network(p['voucher_url'],
                        width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Text('📄 Ver voucher',
                                style:
                                    TextStyle(color: AppColors.texto2)))),
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
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
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
                border:
                    Border.all(color: AppColors.amarillo.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.hourglass_empty,
                    color: AppColors.amarillo, size: 16),
                SizedBox(width: 8),
                Text('Esperando que el cliente suba el voucher',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.amarillo)),
              ]),
            ),
          ),
        ],

        // Botones aprobar/rechazar
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
                      onPressed: () =>
                          _verificarPago(p['id'], 'aprobar'),
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
                fontWeight: FontWeight.w700)));

  Color _colorEstado(String e) {
    switch (e) {
      case 'verificado': return AppColors.verde;
      case 'pendiente':  return AppColors.amarillo;
      case 'rechazado':  return AppColors.rojo;
      default:           return AppColors.texto2;
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'verificado': return '✅ VERIFICADO';
      case 'pendiente':  return '⏳ PENDIENTE';
      case 'rechazado':  return '❌ RECHAZADO';
      default:           return e.toUpperCase();
    }
  }

  Color _colorMetodo(String m) {
    switch (m) {
      case 'yape':         return const Color(0xFF7B2FBE);
      case 'plin':         return AppColors.azul;
      case 'transferencia': return AppColors.verde;
      default:             return AppColors.texto2;
    }
  }

  String _iconoMetodo(String m) {
    switch (m) {
      case 'yape':         return '📱';
      case 'plin':         return '💙';
      case 'transferencia': return '🏦';
      case 'efectivo':     return '💵';
      default:             return '💳';
    }
  }
}
