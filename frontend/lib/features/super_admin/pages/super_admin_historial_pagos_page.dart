import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminHistorialPagosPage extends StatefulWidget {
  const SuperAdminHistorialPagosPage({super.key});
  @override
  State<SuperAdminHistorialPagosPage> createState() => _State();
}

class _State extends State<SuperAdminHistorialPagosPage> {
  List<dynamic> _todos = [];
  bool _loading = true;
  String? _error;
  String _filtro = 'todos';
  int _page = 0;
  Timer? _timer;

  static const double _overhead   = 200.0;
  static const double _cardHeight = 115.0;

  static const _filtros = [
    {'key': 'todos',     'label': 'Todos',     'color': null},
    {'key': 'activo',    'label': 'Aprobados', 'color': AppColors.verde},
    {'key': 'pendiente', 'label': 'Pendientes','color': AppColors.amarillo},
    {'key': 'rechazado', 'label': 'Rechazados','color': AppColors.rojo},
    {'key': 'vencido',   'label': 'Vencidos',  'color': AppColors.texto2},
  ];

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
      final Map<String, dynamic> params = _filtro == 'todos' ? {} : {'estado': _filtro};
      final res = await ApiClient().dio.get(
        ApiConstants.superAdminHistorialPagos,
        queryParameters: params,
      );
      setState(() { _todos = res.data; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error al cargar historial'; _loading = false; });
    }
  }

  void _setFiltro(String f) {
    if (_filtro == f) return;
    setState(() { _filtro = f; _page = 0; });
    _cargar();
  }

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    final ps    = _pageSize(context);
    final total = (_todos.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _todos.skip(page * ps).take(ps).toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Filtros ──────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filtros.map((f) {
                final active = _filtro == f['key'];
                final color  = (f['color'] as Color?) ?? AppColors.amarillo;
                return GestureDetector(
                  onTap: () => _setFiltro(f['key'] as String),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? color.withOpacity(0.15) : AppColors.negro2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? color : AppColors.borde,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? color : AppColors.texto2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Lista ──────────────────────────────────
          if (_todos.isEmpty)
            const Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('📭', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('Sin registros', style: TextStyle(color: AppColors.texto2, fontSize: 15)),
                ]),
              ),
            )
          else ...[
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (_, i) => _buildCard(items[i]),
              ),
            ),
            if (total > 1) _paginacion(total, page),
          ],
        ]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> s) {
    final estado  = s['estado'] as String? ?? '';
    final color   = _colorEstado(estado);
    final label   = _labelEstado(estado);
    final icono   = _iconoMetodo(s['metodo_pago'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila 1: admin + monto
        Row(children: [
          Expanded(
            child: Text(
              s['admin_nombre'] ?? '—',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'S/.${(s['monto'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ]),
        const SizedBox(height: 4),
        // Fila 2: celular + plan + método
        Row(children: [
          Text(
            '+51 ${s['admin_celular'] ?? ''} · ${(s['plan'] as String?)?.toUpperCase() ?? ''} · $icono ${(s['metodo_pago'] as String?)?.toUpperCase() ?? ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.texto2),
          ),
        ]),
        const SizedBox(height: 6),
        // Fila 3: estado + fechas
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          if (s['fecha_pago'] != null)
            Text('Pagado: ${s['fecha_pago']}', style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          if (s['fecha_vencimiento'] != null) ...[
            const Text(' · ', style: TextStyle(color: AppColors.borde)),
            Text('Vence: ${s['fecha_vencimiento']}', style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          ],
          if (s['fecha_pago'] == null && s['created_at'] != null)
            Text('Enviado: ${s['created_at']}', style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
        ]),
        // Fila 4: motivo rechazo (solo si aplica)
        if (estado == 'rechazado' && s['motivo_rechazo'] != null) ...[
          const SizedBox(height: 4),
          Text(
            '⚠️ ${s['motivo_rechazo']}',
            style: const TextStyle(fontSize: 11, color: AppColors.rojo),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ]),
    );
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'activo':    return AppColors.verde;
      case 'pendiente': return AppColors.amarillo;
      case 'rechazado': return AppColors.rojo;
      case 'vencido':   return AppColors.texto2;
      default:          return AppColors.borde;
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'activo':    return 'APROBADO';
      case 'pendiente': return 'PENDIENTE';
      case 'rechazado': return 'RECHAZADO';
      case 'vencido':   return 'VENCIDO';
      default:          return e.toUpperCase();
    }
  }

  String _iconoMetodo(String m) {
    switch (m.toLowerCase()) {
      case 'yape':          return '💜';
      case 'plin':          return '🟢';
      case 'transferencia': return '🏦';
      default:              return '💳';
    }
  }

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _arrowBtn(Icons.arrow_back_ios_new, current > 0,
            () => setState(() => _page = current - 1)),
        ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
        if (total > 9)
          Text('${current + 1} / $total',
              style: const TextStyle(color: AppColors.amarillo, fontSize: 14, fontWeight: FontWeight.w700)),
        _arrowBtn(Icons.arrow_forward_ios, current < total - 1,
            () => setState(() => _page = current + 1)),
      ],
    ),
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => IconButton(
    icon: Icon(icon, size: 16,
        color: enabled ? AppColors.amarillo : AppColors.borde),
    onPressed: enabled ? onTap : null,
  );

  Widget _pageNum(int i, int current) {
    final active = i == current;
    return GestureDetector(
      onTap: () => setState(() => _page = i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: active ? AppColors.amarillo.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? AppColors.amarillo : AppColors.borde,
          ),
        ),
        child: Center(
          child: Text('${i + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppColors.amarillo : AppColors.texto2,
              )),
        ),
      ),
    );
  }
}
