import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminReservasPage extends StatefulWidget {
  const AdminReservasPage({super.key});
  @override
  State<AdminReservasPage> createState() => _State();
}

class _State extends State<AdminReservasPage> {
  List<dynamic> _reservas = [];
  bool _loading = true;
  String? _error;
  String _filtroEstado = 'todos';
  int _page = 0;

  // Overhead: appbar(56) + tabbar(48) + filterbar(96) + toppad(12) + pagination(50) + margins(24)
  static const double _overhead   = 286.0;
  static const double _cardHeight = 118.0;

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
      final params = _filtroEstado != 'todos' ? {'estado': _filtroEstado} : <String, dynamic>{};
      final res = await ApiClient().dio.get(ApiConstants.adminReservas, queryParameters: params);
      setState(() { _reservas = res.data; _loading = false; });
    } catch (e) {
      String msg = 'Error al cargar reservas';
      final err = e.toString().toLowerCase();
      if (err.contains('401') || err.contains('403')) msg = 'Sin permisos — verifica tu sesión';
      else if (err.contains('timeout'))    msg = 'Tiempo de espera agotado';
      else if (err.contains('connection')) msg = 'Sin conexión — verifica tu red';
      setState(() { _error = msg; _loading = false; });
    }
  }

  Future<void> _cambiarEstado(String reservaId, String accion) async {
    try {
      await ApiClient().dio.patch('/admin/reservas/$reservaId/estado', data: {'estado': accion});
      _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accion == 'confirmed' ? '✅ Reserva confirmada' : '❌ Reserva cancelada'),
        backgroundColor: accion == 'confirmed' ? AppColors.verde : AppColors.rojo,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar'), backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _confirmarAccion(String? id, String accion) async {
    if (id == null) return;
    final label = accion == 'confirmed' ? 'confirmar' : 'cancelar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: Text('¿Seguro que deseas $label esta reserva?',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: AppColors.texto2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: accion == 'confirmed' ? AppColors.verde : AppColors.rojo,
                foregroundColor: AppColors.negro),
            child: Text(accion == 'confirmed' ? 'Confirmar' : 'Cancelar'),
          ),
        ],
      ),
    );
    if (ok == true) _cambiarEstado(id, accion);
  }

  void _mostrarDetalle(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _DetalleReservaSheet(reserva: r, onCambiarEstado: _cambiarEstado),
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
            GestureDetector(onTap: _cargar,
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
                  color: _filtroEstado == f.$1 ? AppColors.verde.withOpacity(0.15) : AppColors.negro3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _filtroEstado == f.$1 ? AppColors.verde : AppColors.borde),
                ),
                child: Text(f.$2, style: TextStyle(
                  fontSize: 12,
                  color: _filtroEstado == f.$1 ? AppColors.verde : AppColors.texto2,
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
            ? const Center(child: CircularProgressIndicator(color: AppColors.verde))
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
                        Text(_filtroEstado == 'todos' ? 'No hay reservas aún'
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
          color: AppColors.verde,
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
    final estado        = r['estado'] ?? '';
    final puedeConfirmar = estado == 'pending';
    final puedeCancelar  = estado == 'pending' || estado == 'confirmed';

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
                style: const TextStyle(fontSize: 12, color: AppColors.texto2, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (r['es_manual'] == true) ...[
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
            _badgeEstado(estado),
          ]),
          const SizedBox(height: 8),
          Text(r['cliente_nombre'] ?? '—',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          if (r['dni_cliente'] != null && (r['dni_cliente'] as String).isNotEmpty)
            Text('DNI: ${r['dni_cliente']}',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
          Text('${r['cancha_nombre'] ?? ''} · ${r['local_nombre'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          const SizedBox(height: 8),
          Row(children: [
            _chip('📅 ${_fmt(r['fecha'])}', AppColors.texto2),
            const SizedBox(width: 6),
            _chip('🕐 ${r['hora_inicio'] ?? ''} - ${r['hora_fin'] ?? ''}', AppColors.texto2),
            const Spacer(),
            Text('S/.${r['precio_total']?.toString() ?? '0'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.verde)),
          ]),
          if (puedeConfirmar || puedeCancelar) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.borde, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              if (puedeCancelar) Expanded(child: OutlinedButton(
                onPressed: () => _confirmarAccion(r['id'], 'canceled'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rojo,
                  side: const BorderSide(color: AppColors.rojo),
                  minimumSize: const Size(0, 34),
                ),
                child: const Text('❌ Cancelar', style: TextStyle(fontSize: 12)),
              )),
              if (puedeConfirmar && puedeCancelar) const SizedBox(width: 8),
              if (puedeConfirmar) Expanded(child: ElevatedButton(
                onPressed: () => _confirmarAccion(r['id'], 'confirmed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde, foregroundColor: AppColors.negro,
                  minimumSize: const Size(0, 34),
                ),
                child: const Text('✅ Confirmar', style: TextStyle(fontSize: 12)),
              )),
            ]),
          ],
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
          style: const TextStyle(color: AppColors.verde, fontSize: 14, fontWeight: FontWeight.w700)),
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
        border: Border.all(color: i == current ? AppColors.verde : Colors.transparent),
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
      child: Icon(icon, size: 16, color: enabled ? AppColors.verde : AppColors.borde),
    ),
  );

  Widget _badgeEstado(String estado) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: _colorEstado(estado).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(_labelEstado(estado),
        style: TextStyle(fontSize: 10, color: _colorEstado(estado), fontWeight: FontWeight.w700)),
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
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
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

// ── Sheet detalle reserva ────────────────────────────────────────
class _DetalleReservaSheet extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final Function(String, String) onCambiarEstado;
  const _DetalleReservaSheet({required this.reserva, required this.onCambiarEstado});

  @override
  Widget build(BuildContext context) {
    final r              = reserva;
    final estado         = r['estado'] ?? '';
    final puedeConfirmar = estado == 'pending';
    final puedeCancelar  = estado == 'pending' || estado == 'confirmed';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Detalle de Reserva',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          _badge(estado),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.negro3, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borde)),
          child: Column(children: [
            _fila('Código',      r['codigo'] ?? '—'),
            _fila('Cliente',     r['cliente_nombre'] ?? '—'),
            _fila('Celular',     '+51 ${r['cliente_celular'] ?? ''}'),
            _fila('Cancha',      r['cancha_nombre'] ?? '—'),
            _fila('Local',       r['local_nombre'] ?? '—'),
            _fila('Fecha',       _fmt(r['fecha'])),
            _fila('Horario',     '${r['hora_inicio'] ?? ''} - ${r['hora_fin'] ?? ''}'),
            _fila('Precio',      'S/.${r['precio_total']?.toString() ?? '0'}'),
            _fila('Método',      r['metodo_pago']?.toString().toUpperCase() ?? 'Pendiente'),
            _fila('Comprobante', r['tipo_doc']?.toString().toUpperCase() ?? '—'),
            if (r['pago_estado'] != null) _fila('Pago', r['pago_estado'].toString().toUpperCase()),
          ]),
        ),
        if (r['voucher_url'] != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(r['voucher_url'], height: 120, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 60, color: AppColors.negro3,
                    child: const Center(child: Text('📄 Voucher adjunto',
                        style: TextStyle(color: AppColors.texto2))))),
          ),
        ],
        const SizedBox(height: 16),
        if (puedeConfirmar || puedeCancelar) Row(children: [
          if (puedeCancelar) Expanded(child: OutlinedButton(
            onPressed: () { Navigator.pop(context); onCambiarEstado(r['id'], 'canceled'); },
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.rojo,
                side: const BorderSide(color: AppColors.rojo)),
            child: const Text('❌ Cancelar'),
          )),
          if (puedeConfirmar && puedeCancelar) const SizedBox(width: 10),
          if (puedeConfirmar) Expanded(child: ElevatedButton(
            onPressed: () { Navigator.pop(context); onCambiarEstado(r['id'], 'confirmed'); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde,
                foregroundColor: AppColors.negro),
            child: const Text('✅ Confirmar'),
          )),
        ]),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: AppColors.texto2))),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _badge(String estado) {
    final map = {
      'confirmed': (AppColors.verde,   '✅ Confirmada'),
      'pending':   (AppColors.amarillo,'⏳ Pendiente'),
      'active':    (AppColors.azul,    '🟢 En juego'),
      'done':      (AppColors.texto2,  '🏁 Finalizada'),
      'canceled':  (AppColors.rojo,    '❌ Cancelada'),
    };
    final c = map[estado] ?? (AppColors.texto2, estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.$1.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.$1.withOpacity(0.3))),
      child: Text(c.$2, style: TextStyle(fontSize: 11, color: c.$1, fontWeight: FontWeight.w700)),
    );
  }

  Widget _fila(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label:', style: const TextStyle(color: AppColors.texto2, fontSize: 13)),
      const Spacer(),
      Text(valor, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}
