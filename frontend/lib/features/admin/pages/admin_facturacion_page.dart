import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _filtro = 'todos';
  int _page = 0;

  // Overhead: appbar(56) + tabbar(48) + banner(46) + stats(72) + filtros(52) + toppad(12) + pagination(50) + margins(20)
  static const double _overhead   = 356.0;
  static const double _cardHeight = 155.0;

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

  static const _filtros = [
    ('todos',    '📋 Todos'),
    ('boleta',   '🧾 Boletas'),
    ('factura',  '📄 Facturas'),
    ('sin_tipo', '❓ Sin tipo'),
  ];

  @override
  void initState() { super.initState(); _cargar(); }

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
      _page = 0;
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
            _statChip('💰 Total',
                'S/.${(_stats!['ingresos_total'] ?? 0.0).toStringAsFixed(0)}', AppColors.verde),
            const SizedBox(width: 8),
            _statChip('📅 Este mes',
                'S/.${(_stats!['ingresos_mes'] ?? 0.0).toStringAsFixed(0)}', AppColors.verde),
            const SizedBox(width: 8),
            GestureDetector(onTap: _cargar,
                child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
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
                color: _filtro == f.$1
                    ? AppColors.verde.withOpacity(0.15) : AppColors.negro3,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _filtro == f.$1 ? AppColors.verde : AppColors.borde),
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

      // Lista paginada
      Expanded(
        child: _filtrados.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🧾', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('No hay registros para este filtro',
                    style: TextStyle(color: AppColors.texto2)),
              ]))
            : _buildLista(context),
      ),
    ]);
  }

  Widget _buildLista(BuildContext context) {
    final ps    = _pageSize(context);
    final total = (_filtrados.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _filtrados.skip(page * ps).take(ps).toList();

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          color: AppColors.verde,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            itemCount: items.length,
            itemBuilder: (_, i) => _cardItem(items[i] as Map<String, dynamic>),
          ),
        ),
      ),
      if (total > 1) ...[
        _paginacion(total, page),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Widget _cardItem(Map<String, dynamic> e) {
    final tipoDoc    = e['tipo_doc'] as String?;
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
          Text(e['codigo'] ?? '—',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          if (e['es_manual'] == true) ...[
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: const Text('MANUAL', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w700)),
            ),
          ],
          _badgeTipoDoc(tipoDoc),
        ]),
        const SizedBox(height: 6),
        Text(e['cliente_nombre'] ?? '—',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: Colors.white)),
        if (e['dni_cliente'] != null && (e['dni_cliente'] as String).isNotEmpty)
          Text('DNI: ${e['dni_cliente']}',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
        Text('+51 ${e['cliente_celular'] ?? ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
        const SizedBox(height: 6),
        Row(children: [
          Text('${e['cancha_nombre'] ?? '—'} · ${_fmt(e['fecha'])}',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          const Spacer(),
          Text('S/.${(e['monto'] ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: AppColors.verde)),
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
        const SizedBox(height: 10),
        Row(children: [
          _accionBtn(Icons.picture_as_pdf_outlined, 'PDF',       AppColors.azul,    () => _exportarPdf(e)),
          const SizedBox(width: 8),
          _accionBtn(Icons.share_outlined,          'Compartir', AppColors.verde,   () => _compartir(e)),
          const SizedBox(width: 8),
          _accionBtn(Icons.print_outlined,          'Imprimir',  AppColors.texto2,  () => _imprimir(e)),
        ]),
      ]),
    );
  }

  // ── Acciones del comprobante ─────────────────────────────────

  void _exportarPdf(Map<String, dynamic> e) {
    final pdfUrl = e['pdf_url'] as String?;
    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: pdfUrl));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('URL del PDF copiada: $pdfUrl'),
        backgroundColor: AppColors.azul,
        duration: const Duration(seconds: 3),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('📄 PDF disponible cuando se active SUNAT (Fase 4)'),
        backgroundColor: AppColors.azul,
        duration: Duration(seconds: 2),
      ));
    }
  }

  void _compartir(Map<String, dynamic> e) {
    final metodoLabel = switch (e['metodo_pago'] as String?) {
      'yape'          => 'Yape',
      'plin'          => 'Plin',
      'transferencia' => 'Transferencia',
      'efectivo'      => 'Efectivo',
      'tarjeta'       => 'Tarjeta',
      _               => e['metodo_pago']?.toString().toUpperCase() ?? '—',
    };
    final texto = '''🏟️ Comprobante PichangaYa
Código: ${e['codigo'] ?? '—'}
Cliente: ${e['cliente_nombre'] ?? '—'}
DNI: ${e['dni_cliente'] ?? '—'}
Tel: +51 ${e['cliente_celular'] ?? '—'}
Cancha: ${e['cancha_nombre'] ?? '—'} · ${_fmt(e['fecha'])}
Monto: S/.${(e['monto'] ?? 0.0).toStringAsFixed(2)}
Método: $metodoLabel
Tipo: ${e['tipo_doc']?.toString().toUpperCase() ?? 'SIN TIPO'}''';

    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('📋 Datos del comprobante copiados al portapapeles'),
      backgroundColor: AppColors.verde,
      duration: Duration(seconds: 2),
    ));
  }

  void _imprimir(Map<String, dynamic> e) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🖨️ Impresión disponible con integración SUNAT (Fase 4)'),
      backgroundColor: AppColors.texto2,
      duration: Duration(seconds: 2),
    ));
  }

  Widget _accionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0,
          () => setState(() => _page = current - 1)),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
      if (total > 9) Text('${current + 1} / $total',
          style: const TextStyle(color: AppColors.verde, fontSize: 14,
              fontWeight: FontWeight.w700)),
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
        color: i == current ? AppColors.verde.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: i == current ? AppColors.verde : Colors.transparent),
      ),
      child: Text('${i + 1}', style: TextStyle(
        fontSize: 13,
        fontWeight: i == current ? FontWeight.w700 : FontWeight.normal,
        color: i == current ? AppColors.verde : AppColors.texto2,
      )),
    ),
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Icon(icon, size: 16,
          color: enabled ? AppColors.verde : AppColors.borde),
    ),
  );

  String _fmt(String? f) {
    if (f == null || f.isEmpty) return '—';
    final dateStr = f.contains('T') ? f.split('T')[0] : f;
    final p = dateStr.split('-');
    if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    return f;
  }

  Widget _badgeTipoDoc(String? tipo) {
    Color color; String label;
    if (tipo == 'boleta')       { color = AppColors.azul;    label = '🧾 BOLETA'; }
    else if (tipo == 'factura') { color = AppColors.naranja; label = '📄 FACTURA'; }
    else                        { color = AppColors.texto2;  label = '❓ SIN TIPO'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color,
          fontWeight: FontWeight.w700)),
    );
  }

  Widget _badgeComprobante(String? estado) {
    Color color; String label;
    if (estado == 'emitido')        { color = AppColors.verde;    label = '✅ EMITIDO'; }
    else if (estado == 'pendiente') { color = AppColors.amarillo; label = '⏳ PENDIENTE'; }
    else if (estado == 'error')     { color = AppColors.rojo;     label = '❌ ERROR'; }
    else                            { color = AppColors.texto2;   label = '— SIN COMPROBANTE'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color,
          fontWeight: FontWeight.w700)),
    );
  }

  Widget _badgeMetodo(String? metodo) {
    final label = switch (metodo) {
      'yape'          => '📱 Yape',
      'plin'          => '💙 Plin',
      'transferencia' => '🏦 Transfer.',
      'efectivo'      => '💵 Efectivo',
      'tarjeta'       => '💳 Tarjeta',
      _               => metodo?.toUpperCase() ?? '—',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.negro3, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.texto2,
          fontWeight: FontWeight.w600)),
    );
  }

  Widget _statChip(String label, String val, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
    ]),
  );
}
