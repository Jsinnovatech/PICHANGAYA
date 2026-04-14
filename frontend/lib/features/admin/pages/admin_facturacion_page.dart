import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class AdminFacturacionPage extends StatefulWidget {
  const AdminFacturacionPage({super.key});
  @override
  State<AdminFacturacionPage> createState() => _State();
}

class _State extends State<AdminFacturacionPage> {
  List<dynamic> _items = [];
  List<dynamic> _filtrados = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  String _filtro = 'todos'; // todos | boleta | factura | sin_tipo

  static const _filtros = [
    ('todos',    '📋 Todos'),
    ('boleta',   '🧾 Boletas'),
    ('factura',  '📄 Facturas'),
    ('sin_tipo', '❓ Sin tipo'),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        ApiClient().dio.get('/admin/facturacion'),
        ApiClient().dio.get('/admin/facturacion/stats'),
      ]);
      setState(() {
        _items = res[0].data;
        _stats = res[1].data;
        _aplicarFiltro();
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'Error al cargar facturación'; _loading = false; });
    }
  }

  void _aplicarFiltro() {
    setState(() {
      _filtrados = _filtro == 'todos'
          ? _items
          : _filtro == 'sin_tipo'
              ? _items.where((e) => e['tipo_doc'] == null).toList()
              : _items.where((e) => e['tipo_doc'] == _filtro).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_error!, style: const TextStyle(color: AppColors.rojo)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
    ]));

    return Column(children: [
      // Banner SUNAT
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: AppColors.azul.withOpacity(0.08),
        child: Row(children: [
          const Icon(Icons.info_outline, color: AppColors.azul, size: 16),
          const SizedBox(width: 8),
          const Expanded(child: Text(
            '🏦 Integración SUNAT (Nubefact) disponible en Fase 4. Historial de pagos verificados.',
            style: TextStyle(fontSize: 11, color: AppColors.azul),
          )),
        ]),
      ),

      // Stats
      if (_stats != null) Container(
        padding: const EdgeInsets.all(12),
        color: AppColors.negro2,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _statChip('🧾 Boletas',  '${_stats!['total_boletas'] ?? 0}',  AppColors.azul),
            const SizedBox(width: 8),
            _statChip('📄 Facturas', '${_stats!['total_facturas'] ?? 0}', AppColors.naranja),
            const SizedBox(width: 8),
            _statChip('❓ Sin tipo',  '${_stats!['sin_comprobante'] ?? 0}', AppColors.texto2),
            const SizedBox(width: 8),
            _statChip('💰 Total',    'S/.${(_stats!['ingresos_total'] ?? 0.0).toStringAsFixed(0)}', AppColors.verde),
            const SizedBox(width: 8),
            _statChip('📅 Este mes', 'S/.${(_stats!['ingresos_mes'] ?? 0.0).toStringAsFixed(0)}', AppColors.verde),
            const SizedBox(width: 8),
            GestureDetector(onTap: _cargar, child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
          ]),
        ),
      ),

      // Filtros
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: AppColors.negro2,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _filtros.map((f) => GestureDetector(
            onTap: () { setState(() => _filtro = f.$1); _aplicarFiltro(); },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _filtro == f.$1 ? AppColors.verde.withOpacity(0.15) : AppColors.negro3,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _filtro == f.$1 ? AppColors.verde : AppColors.borde),
              ),
              child: Text(f.$2, style: TextStyle(
                fontSize: 12,
                color: _filtro == f.$1 ? AppColors.verde : AppColors.texto2,
                fontWeight: _filtro == f.$1 ? FontWeight.w700 : FontWeight.normal,
              )),
            ),
          )).toList()),
        ),
      ),

      // Lista
      Expanded(
        child: _filtrados.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🧾', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('No hay registros para este filtro', style: TextStyle(color: AppColors.texto2)),
              ]))
            : RefreshIndicator(
                onRefresh: _cargar,
                color: AppColors.verde,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) => _cardItem(_filtrados[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _cardItem(Map<String, dynamic> e) {
    final tipoDoc = e['tipo_doc'] as String?;
    final compEstado = e['comprobante_estado'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(e['codigo'] ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.texto2, fontWeight: FontWeight.w600)),
          const Spacer(),
          _badgeTipoDoc(tipoDoc),
        ]),
        const SizedBox(height: 6),
        Text(e['cliente_nombre'] ?? '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('+51 ${e['cliente_celular'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
        const SizedBox(height: 6),
        Row(children: [
          Text('${e['cancha_nombre'] ?? '—'} · ${e['fecha'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          const Spacer(),
          Text('S/.${(e['monto'] ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.verde)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _badgeMetodo(e['metodo_pago'] as String?),
          const SizedBox(width: 6),
          _badgeComprobante(compEstado),
          if (e['comprobante_serie'] != null) ...[
            const SizedBox(width: 6),
            Text('${e['comprobante_serie']}-${e['comprobante_numero']}',
                style: const TextStyle(fontSize: 10, color: AppColors.texto2)),
          ],
        ]),
        if (e['pdf_url'] != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('PDF: ${e['pdf_url']}'),
                backgroundColor: AppColors.azul,
              ));
            },
            child: const Text('📄 Ver PDF', style: TextStyle(fontSize: 12, color: AppColors.azul, decoration: TextDecoration.underline)),
          ),
        ] else ...[
          const SizedBox(height: 6),
          const Text('⏳ Integración SUNAT Fase 4', style: TextStyle(fontSize: 11, color: AppColors.texto2, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  Widget _badgeTipoDoc(String? tipo) {
    Color color; String label;
    if (tipo == 'boleta') { color = AppColors.azul; label = '🧾 BOLETA'; }
    else if (tipo == 'factura') { color = AppColors.naranja; label = '📄 FACTURA'; }
    else { color = AppColors.texto2; label = '❓ SIN TIPO'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _badgeComprobante(String? estado) {
    Color color; String label;
    if (estado == 'emitido') { color = AppColors.verde; label = '✅ EMITIDO'; }
    else if (estado == 'pendiente') { color = AppColors.amarillo; label = '⏳ PENDIENTE'; }
    else if (estado == 'error') { color = AppColors.rojo; label = '❌ ERROR'; }
    else { color = AppColors.texto2; label = '— SIN COMPROBANTE'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _badgeMetodo(String? metodo) {
    final label = switch (metodo) {
      'yape' => '📱 Yape', 'plin' => '💙 Plin',
      'transferencia' => '🏦 Transfer.', 'efectivo' => '💵 Efectivo',
      'tarjeta' => '💳 Tarjeta', _ => metodo?.toUpperCase() ?? '—',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.negro3, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.texto2, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statChip(String label, String val, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
    ]),
  );
}
