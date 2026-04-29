import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class SuperAdminReservasPage extends StatefulWidget {
  const SuperAdminReservasPage({super.key});
  @override
  State<SuperAdminReservasPage> createState() => _State();
}

class _State extends State<SuperAdminReservasPage> {
  List<dynamic> _reservas = [];
  bool _loading = true;
  String? _error;
  String _filtroEstado = 'todos';
  int _page = 0;

  static const double _overhead   = 286.0;
  static const double _cardHeight = 128.0;

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(1, 20);
  }

  static const _filtros = [
    ('todos',     'Todos'),
    ('pending',   'Pendientes'),
    ('confirmed', 'Confirmadas'),
    ('active',    'En Juego'),
    ('done',      'Finalizadas'),
    ('canceled',  'Canceladas'),
  ];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = _filtroEstado != 'todos'
          ? {'estado': _filtroEstado}
          : <String, dynamic>{};
      final res = await ApiClient().dio.get(
        ApiConstants.superAdminReservas,
        queryParameters: params,
      );
      setState(() { _reservas = res.data; _loading = false; });
    } catch (e) {
      String msg = 'Error al cargar reservas';
      final err = e.toString().toLowerCase();
      if (err.contains('401') || err.contains('403')) msg = 'Sin permisos';
      else if (err.contains('timeout')) msg = 'Tiempo de espera agotado';
      else if (err.contains('connection')) msg = 'Sin conexión';
      setState(() { _error = msg; _loading = false; });
    }
  }

  void _mostrarDetalle(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _DetalleSheet(reserva: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Filtros ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: AppColors.negro2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Filtrar:', style: TextStyle(fontSize: 12, color: AppColors.texto2)),
            const Spacer(),
            GestureDetector(
                onTap: _cargar,
                child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _filtros.map((f) => GestureDetector(
              onTap: () { setState(() { _filtroEstado = f.$1; _page = 0; }); _cargar(); },
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _filtroEstado == f.$1
                      ? AppColors.amarillo.withOpacity(0.15)
                      : AppColors.negro3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _filtroEstado == f.$1 ? AppColors.amarillo : AppColors.borde),
                ),
                child: Text(f.$2, style: TextStyle(
                  fontSize: 12,
                  color: _filtroEstado == f.$1 ? AppColors.amarillo : AppColors.texto2,
                  fontWeight: _filtroEstado == f.$1 ? FontWeight.w700 : FontWeight.normal,
                )),
              ),
            )).toList()),
          ),
        ]),
      ),

      // ── Contenido ────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.amarillo))
            : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_error!, style: const TextStyle(color: AppColors.rojo)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                  ]))
                : _reservas.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('📋', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          _filtroEstado == 'todos'
                              ? 'No hay reservas aún'
                              : 'No hay reservas con este estado',
                          style: const TextStyle(color: AppColors.texto2)),
                      ]))
                    : _buildLista(context),
      ),
    ]);
  }

  Widget _buildLista(BuildContext context) {
    final ps    = _pageSize(context);
    final total = (_reservas.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _reservas.skip(page * ps).take(ps).toList();

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          color: AppColors.amarillo,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _cardReserva(items[i] as Map<String, dynamic>),
            ),
          ),
        ),
      ),
      if (total > 1) ...[
        _paginacion(total, page),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Widget _cardReserva(Map<String, dynamic> r) {
    final estado = r['estado'] ?? '';
    return GestureDetector(
      onTap: () => _mostrarDetalle(r),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colorEstado(estado).withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(r['codigo'] ?? '—',
                style: const TextStyle(fontSize: 12, color: AppColors.texto2,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            _badgeEstado(estado),
          ]),
          const SizedBox(height: 6),
          Text(r['cliente_nombre'] ?? '—',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text('${r['cancha_nombre'] ?? ''} · ${r['local_nombre'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          if (r['admin_nombre'] != null)
            Text('Admin: ${r['admin_nombre']}',
                style: const TextStyle(fontSize: 11, color: AppColors.amarillo)),
          const SizedBox(height: 8),
          Row(children: [
            _chip('📅 ${_fmt(r['fecha'])}', AppColors.texto2),
            const SizedBox(width: 6),
            _chip('🕐 ${r['hora_inicio'] ?? ''} - ${r['hora_fin'] ?? ''}',
                AppColors.texto2),
            const Spacer(),
            Text('S/.${r['precio_total']?.toString() ?? '0'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.verde)),
          ]),
        ]),
      ),
    );
  }

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0,
          () => setState(() => _page = current - 1)),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
      if (total > 9) Text('${current + 1} / $total',
          style: const TextStyle(color: AppColors.amarillo, fontSize: 14,
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
        color: i == current ? AppColors.amarillo.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: i == current ? AppColors.amarillo : Colors.transparent),
      ),
      child: Text('${i + 1}', style: TextStyle(
        fontSize: 13,
        fontWeight: i == current ? FontWeight.w700 : FontWeight.normal,
        color: i == current ? AppColors.amarillo : AppColors.texto2,
      )),
    ),
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(icon, size: 16,
              color: enabled ? AppColors.amarillo : AppColors.borde),
        ),
      );

  Widget _badgeEstado(String estado) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: _colorEstado(estado).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(_labelEstado(estado),
        style: TextStyle(fontSize: 10, color: _colorEstado(estado),
            fontWeight: FontWeight.w700)),
  );

  String _fmt(String? f) {
    if (f == null || f.isEmpty) return '—';
    final dateStr = f.contains('T') ? f.split('T')[0] : f;
    final p = dateStr.split('-');
    if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    return f;
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );

  Color _colorEstado(String e) {
    switch (e) {
      case 'confirmed': return AppColors.verde;
      case 'pending':   return AppColors.amarillo;
      case 'active':    return AppColors.azul;
      case 'done':      return AppColors.texto2;
      case 'canceled':  return AppColors.rojo;
      default:          return AppColors.texto2;
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'confirmed': return '✅ Confirmada';
      case 'pending':   return '⏳ Pendiente';
      case 'active':    return '🟢 En juego';
      case 'done':      return '🏁 Finalizada';
      case 'canceled':  return '❌ Cancelada';
      default:          return e.toUpperCase();
    }
  }
}

// ── Sheet detalle ────────────────────────────────────────────────
class _DetalleSheet extends StatelessWidget {
  final Map<String, dynamic> reserva;
  const _DetalleSheet({required this.reserva});

  @override
  Widget build(BuildContext context) {
    final r      = reserva;
    final estado = r['estado'] ?? '';

    final colorEstado = _color(estado);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Detalle de Reserva',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const Spacer(),
          _badge(estado, colorEstado),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.negro3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borde)),
          child: Column(children: [
            _fila('Código',      r['codigo'] ?? '—'),
            _fila('Cliente',     r['cliente_nombre'] ?? '—'),
            _fila('Celular',     '+51 ${r['cliente_celular'] ?? ''}'),
            _fila('Cancha',      r['cancha_nombre'] ?? '—'),
            _fila('Local',       r['local_nombre'] ?? '—'),
            _fila('Admin',       r['admin_nombre'] ?? '—'),
            _fila('Fecha',       _fmt(r['fecha'])),
            _fila('Horario',     '${r['hora_inicio'] ?? ''} - ${r['hora_fin'] ?? ''}'),
            _fila('Precio',      'S/.${r['precio_total']?.toString() ?? '0'}'),
            _fila('Método',      r['metodo_pago']?.toString().toUpperCase() ?? 'Pendiente'),
            _fila('Comprobante', r['tipo_doc']?.toString().toUpperCase() ?? '—'),
            if (r['pago_estado'] != null)
              _fila('Pago', r['pago_estado'].toString().toUpperCase()),
          ]),
        ),
        const SizedBox(height: 16),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: AppColors.texto2))),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _badge(String estado, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(_label(estado),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );

  Widget _fila(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label:', style: const TextStyle(color: AppColors.texto2, fontSize: 13)),
      const Spacer(),
      Text(valor,
          style: const TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w600)),
    ]),
  );

  Color _color(String e) {
    switch (e) {
      case 'confirmed': return AppColors.verde;
      case 'pending':   return AppColors.amarillo;
      case 'active':    return AppColors.azul;
      case 'done':      return AppColors.texto2;
      case 'canceled':  return AppColors.rojo;
      default:          return AppColors.texto2;
    }
  }

  String _label(String e) {
    switch (e) {
      case 'confirmed': return '✅ Confirmada';
      case 'pending':   return '⏳ Pendiente';
      case 'active':    return '🟢 En juego';
      case 'done':      return '🏁 Finalizada';
      case 'canceled':  return '❌ Cancelada';
      default:          return e.toUpperCase();
    }
  }
}
