import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminFacturacionPage extends StatefulWidget {
  const AdminFacturacionPage({super.key});
  @override
  State<AdminFacturacionPage> createState() => _AdminFacturacionPageState();
}

class _AdminFacturacionPageState extends State<AdminFacturacionPage> {
  List<Map<String, dynamic>> _reservas = [];
  bool _loading = true;
  String? _error;

  // Stats resumen
  int    _totalBoletas   = 0;
  int    _totalFacturas  = 0;
  double _totalMes       = 0;
  int    _pendientesEmitir = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(
          ApiConstants.adminReservas,
          queryParameters: {'estado': 'done'});

      final lista = (res.data as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      int boletas = 0, facturas = 0, pendientes = 0;
      double total = 0;

      for (final r in lista) {
        final tipo = r['tipo_doc']?.toString() ?? 'boleta';
        final pagado = r['pago_estado'] == 'verificado';
        if (tipo == 'factura') facturas++; else boletas++;
        if (pagado) total += (r['precio_total'] ?? 0).toDouble();
        // Pendiente de emitir = tiene pago verificado pero no tiene nubefact_id
        if (pagado && (r['nubefact_id'] == null || r['nubefact_id'] == '')) {
          pendientes++;
        }
      }

      setState(() {
        _reservas        = lista;
        _totalBoletas    = boletas;
        _totalFacturas   = facturas;
        _totalMes        = total;
        _pendientesEmitir = pendientes;
        _loading         = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar facturación'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]));
    }

    return Column(children: [
      // ── Resumen stats ────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: AppColors.negro2,
        child: Column(children: [
          Row(children: [
            const Text('FACTURACIÓN · SUNAT',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.5)),
            const Spacer(),
            GestureDetector(onTap: _cargar,
                child: const Icon(Icons.refresh,
                    color: AppColors.texto2, size: 16)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _stat('💰 Total', 'S/.${_totalMes.toStringAsFixed(0)}',
                AppColors.verde),
            const SizedBox(width: 8),
            _stat('🧾 Boletas', '$_totalBoletas', AppColors.azul),
            const SizedBox(width: 8),
            _stat('🏢 Facturas', '$_totalFacturas', AppColors.morado),
            const SizedBox(width: 8),
            _stat('⏳ Por emitir', '$_pendientesEmitir', AppColors.amarillo),
          ]),
        ]),
      ),

      // ── Grid tarjetas ────────────────────────────────────
      Expanded(
        child: _reservas.isEmpty
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🧾', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('No hay comprobantes aún',
                  style: TextStyle(color: AppColors.texto2, fontSize: 15)),
            ]))
          : RefreshIndicator(
              onRefresh: _cargar,
              color: AppColors.verde,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: _reservas.length,
                itemBuilder: (_, i) => _cardFactura(_reservas[i]),
              ),
            ),
      ),
    ]);
  }

  Widget _cardFactura(Map<String, dynamic> r) {
    final tipo       = r['tipo_doc']?.toString() ?? 'boleta';
    final esFactura  = tipo == 'factura';
    final pagado     = r['pago_estado'] == 'verificado';
    final emitido    = r['nubefact_id'] != null && r['nubefact_id'] != '';
    final precio     = (r['precio_total'] ?? 0).toDouble();
    final base       = precio / 1.18;
    final igv        = precio - base;
    final codigo     = r['codigo']?.toString() ?? '—';
    final colorTipo  = esFactura ? AppColors.morado : AppColors.azul;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: emitido
                ? AppColors.verde.withOpacity(0.4)
                : colorTipo.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Tipo + código ──────────────────────────────
            Row(children: [
              Text(esFactura ? '🏢' : '🧾',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tipo.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: colorTipo, letterSpacing: 1)),
                Text('· $codigo',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.texto2)),
              ])),
            ]),

            const SizedBox(height: 10),
            const Divider(color: AppColors.borde, height: 1),
            const SizedBox(height: 10),

            // ── Datos ──────────────────────────────────────
            _fila('Cliente',
                r['cliente_nombre']?.toString() ?? '—'),
            _fila('Cancha',
                r['cancha_nombre']?.toString() ?? '—'),
            _fila('Fecha', r['fecha']?.toString() ?? '—'),
            _fila('Hora',
                '${r['hora_inicio'] ?? ''}-${r['hora_fin'] ?? ''}'),

            const SizedBox(height: 8),
            const Divider(color: AppColors.borde, height: 1),
            const SizedBox(height: 8),

            // ── Montos ─────────────────────────────────────
            _filaMonto('Base', 'S/.${base.toStringAsFixed(2)}',
                AppColors.texto2),
            _filaMonto('IGV 18%', 'S/.${igv.toStringAsFixed(2)}',
                AppColors.texto2),
            const SizedBox(height: 4),
            Row(children: [
              const Text('TOTAL',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const Spacer(),
              Text('S/.${precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: AppColors.verde)),
            ]),

            const Spacer(),

            // ── Botón o badge ──────────────────────────────
            if (emitido)
              // Ya emitido — mostrar número de comprobante
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.verde.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.verde.withOpacity(0.4))),
                child: Row(children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.verde, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                      r['nubefact_id']?.toString() ?? 'Emitido',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.verde,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis)),
                ]),
              )
            else if (pagado)
              // Pago verificado pero sin emitir — botón SUNAT
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarInfoSUNAT(r),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verde,
                    foregroundColor: AppColors.negro,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.upload_outlined, size: 14),
                  label: const Text('Emitir SUNAT',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              )
            else
              // Pago pendiente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.amarillo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.amarillo.withOpacity(0.3))),
                child: const Row(children: [
                  Icon(Icons.hourglass_empty,
                      color: AppColors.amarillo, size: 13),
                  SizedBox(width: 6),
                  Text('Pago pendiente',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.amarillo)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarInfoSUNAT(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.borde,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('EMISIÓN ELECTRÓNICA SUNAT',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: AppColors.verde, letterSpacing: 0.5)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.negro3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde)),
            child: Column(children: [
              _filaDetalle('Código',   r['codigo']?.toString() ?? '—'),
              _filaDetalle('Tipo',
                  (r['tipo_doc'] ?? 'boleta').toString().toUpperCase()),
              _filaDetalle('Cliente', r['cliente_nombre']?.toString() ?? '—'),
              _filaDetalle('Cancha',  r['cancha_nombre']?.toString() ?? '—'),
              _filaDetalle('Fecha',   r['fecha']?.toString() ?? '—'),
              _filaDetalle('Total',
                  'S/.${(r['precio_total'] ?? 0).toStringAsFixed(2)}'),
            ]),
          ),
          const SizedBox(height: 16),

          // Aviso Fase 4
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.amarillo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.amarillo.withOpacity(0.3))),
            child: const Row(children: [
              Icon(Icons.info_outline,
                  color: AppColors.amarillo, size: 18),
              SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fase 4 — Nubefact API',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.amarillo)),
                SizedBox(height: 3),
                Text(
                    'La emisión electrónica a SUNAT se integrará con la API de Nubefact en la Fase 4 del proyecto.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.amarillo)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar',
                  style: TextStyle(color: AppColors.texto2))),
        ]),
      ),
    );
  }

  Widget _fila(String label, String valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(
            fontSize: 10, color: AppColors.texto2)),
        Expanded(child: Text(valor,
            style: const TextStyle(
                fontSize: 10, color: Colors.white,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
      ]));

  Widget _filaMonto(String label, String valor, Color color) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: [
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            const Spacer(),
            Text(valor, style: TextStyle(fontSize: 10, color: color)),
          ]));

  Widget _filaDetalle(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('$l:', style: const TextStyle(
            color: AppColors.texto2, fontSize: 13)),
        const Spacer(),
        Text(v, style: const TextStyle(
            color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w600)),
      ]));

  Widget _stat(String label, String valor, Color color) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.25))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor, style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(
                fontSize: 9, color: color.withOpacity(0.8))),
          ])));
}
