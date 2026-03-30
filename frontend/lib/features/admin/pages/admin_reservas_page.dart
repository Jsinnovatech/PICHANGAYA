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

  static const _filtros = [
    ('todos', 'Todos'),
    ('pending', 'Pendientes'),
    ('confirmed', 'Confirmadas'),
    ('active', 'En Juego'),
    ('done', 'Finalizadas'),
    ('canceled', 'Canceladas'),
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
      final params = _filtroEstado != 'todos'
          ? {'estado': _filtroEstado}
          : <String, dynamic>{};
      final res = await ApiClient().dio.get(
            ApiConstants.adminReservas,
            queryParameters: params,
          );
      setState(() {
        _reservas = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar reservas';
        _loading = false;
      });
    }
  }

  Future<void> _cambiarEstado(String reservaId, String accion) async {
    // accion: 'confirmed' | 'canceled'
    try {
      await ApiClient().dio.patch(
        '/admin/reservas/$reservaId/estado',
        data: {'estado': accion},
      );
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accion == 'confirmed'
              ? '✅ Reserva confirmada'
              : '❌ Reserva cancelada'),
          backgroundColor:
              accion == 'confirmed' ? AppColors.verde : AppColors.rojo,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  void _mostrarDetalle(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _DetalleReservaSheet(
        reserva: r,
        onCambiarEstado: _cambiarEstado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Filtros ────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: AppColors.negro2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Filtrar por estado:',
                style: TextStyle(fontSize: 12, color: AppColors.texto2)),
            const Spacer(),
            GestureDetector(
              onTap: _cargar,
              child:
                  const Icon(Icons.refresh, color: AppColors.texto2, size: 18),
            ),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: _filtros
                    .map((f) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _filtroEstado = f.$1;
                            });
                            _cargar();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _filtroEstado == f.$1
                                  ? AppColors.verde.withOpacity(0.15)
                                  : AppColors.negro3,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _filtroEstado == f.$1
                                    ? AppColors.verde
                                    : AppColors.borde,
                              ),
                            ),
                            child: Text(f.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _filtroEstado == f.$1
                                      ? AppColors.verde
                                      : AppColors.texto2,
                                  fontWeight: _filtroEstado == f.$1
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                )),
                          ),
                        ))
                    .toList()),
          ),
        ]),
      ),

      // ── Contenido ──────────────────────────────────────────
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
                : _reservas.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Text('📋', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text(
                              _filtroEstado == 'todos'
                                  ? 'No hay reservas aún'
                                  : 'No hay reservas con este estado',
                              style: const TextStyle(color: AppColors.texto2),
                            ),
                          ]))
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        color: AppColors.verde,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _reservas.length,
                          itemBuilder: (_, i) => _cardReserva(_reservas[i]),
                        ),
                      ),
      ),
    ]);
  }

  Widget _cardReserva(Map<String, dynamic> r) {
    final estado = r['estado'] ?? '';
    final puedeConfirmar = estado == 'pending';
    final puedeCancelar = estado == 'pending' || estado == 'confirmed';

    return GestureDetector(
      onTap: () => _mostrarDetalle(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _colorEstado(estado).withOpacity(0.3),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Código + estado
          Row(children: [
            Text(r['codigo'] ?? '—',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.texto2,
                  fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            _badgeEstado(estado),
          ]),
          const SizedBox(height: 8),
          // Cliente + cancha
          Text(r['cliente_nombre'] ?? '—',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          Text('${r['cancha_nombre'] ?? ''} · ${r['local_nombre'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          const SizedBox(height: 8),
          // Fecha + hora + precio
          Row(children: [
            _chip('📅 ${r['fecha'] ?? ''}', AppColors.texto2),
            const SizedBox(width: 6),
            _chip('🕐 ${r['hora_inicio'] ?? ''} - ${r['hora_fin'] ?? ''}',
                AppColors.texto2),
            const Spacer(),
            Text('S/.${r['precio_total']?.toString() ?? '0'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.verde,
                )),
          ]),
          // Botones rápidos solo en pendientes
          if (puedeConfirmar || puedeCancelar) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.borde, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              if (puedeCancelar)
                Expanded(
                    child: OutlinedButton(
                  onPressed: () => _confirmarAccion(r['id'], 'canceled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rojo,
                    side: const BorderSide(color: AppColors.rojo),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child:
                      const Text('❌ Cancelar', style: TextStyle(fontSize: 12)),
                )),
              if (puedeConfirmar && puedeCancelar) const SizedBox(width: 8),
              if (puedeConfirmar)
                Expanded(
                    child: ElevatedButton(
                  onPressed: () => _confirmarAccion(r['id'], 'confirmed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verde,
                    foregroundColor: AppColors.negro,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child:
                      const Text('✅ Confirmar', style: TextStyle(fontSize: 12)),
                )),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _confirmarAccion(String? id, String accion) async {
    if (id == null) return;
    final label = accion == 'confirmed' ? 'confirmar' : 'cancelar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: Text('¿Seguro que deseas $label esta reserva?',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: AppColors.texto2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  accion == 'confirmed' ? AppColors.verde : AppColors.rojo,
              foregroundColor: AppColors.negro,
            ),
            child: Text(accion == 'confirmed' ? 'Confirmar' : 'Cancelar'),
          ),
        ],
      ),
    );
    if (confirm == true) _cambiarEstado(id, accion);
  }

  Widget _badgeEstado(String estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _colorEstado(estado).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_labelEstado(estado),
          style: TextStyle(
            fontSize: 10,
            color: _colorEstado(estado),
            fontWeight: FontWeight.w700,
          )),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'confirmed':
        return AppColors.verde;
      case 'pending':
        return AppColors.amarillo;
      case 'active':
        return AppColors.azul;
      case 'done':
        return AppColors.texto2;
      case 'canceled':
        return AppColors.rojo;
      default:
        return AppColors.texto2;
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'confirmed':
        return '✅ Confirmada';
      case 'pending':
        return '⏳ Pendiente';
      case 'active':
        return '🟢 En juego';
      case 'done':
        return '🏁 Finalizada';
      case 'canceled':
        return '❌ Cancelada';
      default:
        return estado.toUpperCase();
    }
  }
}

// ══════════════════════════════════════════════
// SHEET DE DETALLE DE RESERVA
// ══════════════════════════════════════════════

class _DetalleReservaSheet extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final Function(String, String) onCambiarEstado;

  const _DetalleReservaSheet({
    required this.reserva,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final estado = r['estado'] ?? '';
    final puedeConfirmar = estado == 'pending';
    final puedeCancelar = estado == 'pending' || estado == 'confirmed';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borde,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(height: 16),

        // Título
        Row(children: [
          const Text('Detalle de Reserva',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          const Spacer(),
          _badge(estado),
        ]),
        const SizedBox(height: 16),

        // Info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borde),
          ),
          child: Column(children: [
            _fila('Código', r['codigo'] ?? '—'),
            _fila('Cliente', r['cliente_nombre'] ?? '—'),
            _fila('Celular', '+51 ${r['cliente_celular'] ?? ''}'),
            _fila('Cancha', r['cancha_nombre'] ?? '—'),
            _fila('Local', r['local_nombre'] ?? '—'),
            _fila('Fecha', r['fecha'] ?? '—'),
            _fila('Horario',
                '${r['hora_inicio'] ?? ''} - ${r['hora_fin'] ?? ''}'),
            _fila('Precio', 'S/.${r['precio_total']?.toString() ?? '0'}'),
            _fila('Método',
                r['metodo_pago']?.toString().toUpperCase() ?? 'Pendiente'),
            _fila(
                'Comprobante', r['tipo_doc']?.toString().toUpperCase() ?? '—'),
            if (r['pago_estado'] != null)
              _fila('Pago', r['pago_estado'].toString().toUpperCase()),
          ]),
        ),

        // Voucher si existe
        if (r['voucher_url'] != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              r['voucher_url'],
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 60,
                color: AppColors.negro3,
                child: const Center(
                  child: Text('📄 Voucher adjunto',
                      style: TextStyle(color: AppColors.texto2)),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Botones
        if (puedeConfirmar || puedeCancelar)
          Row(children: [
            if (puedeCancelar)
              Expanded(
                  child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onCambiarEstado(r['id'], 'canceled');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rojo,
                  side: const BorderSide(color: AppColors.rojo),
                ),
                child: const Text('❌ Cancelar'),
              )),
            if (puedeConfirmar && puedeCancelar) const SizedBox(width: 10),
            if (puedeConfirmar)
              Expanded(
                  child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onCambiarEstado(r['id'], 'confirmed');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: AppColors.negro,
                ),
                child: const Text('✅ Confirmar'),
              )),
          ]),

        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cerrar', style: TextStyle(color: AppColors.texto2)),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _badge(String estado) {
    Color color;
    String label;
    switch (estado) {
      case 'confirmed':
        color = AppColors.verde;
        label = '✅ Confirmada';
        break;
      case 'pending':
        color = AppColors.amarillo;
        label = '⏳ Pendiente';
        break;
      case 'active':
        color = AppColors.azul;
        label = '🟢 En juego';
        break;
      case 'done':
        color = AppColors.texto2;
        label = '🏁 Finalizada';
        break;
      case 'canceled':
        color = AppColors.rojo;
        label = '❌ Cancelada';
        break;
      default:
        color = AppColors.texto2;
        label = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w700,
          )),
    );
  }

  Widget _fila(String label, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text('$label:',
              style: const TextStyle(
                color: AppColors.texto2,
                fontSize: 13,
              )),
          const Spacer(),
          Text(valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ]),
      );
}
