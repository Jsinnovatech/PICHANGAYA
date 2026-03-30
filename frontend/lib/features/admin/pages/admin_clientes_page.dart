import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminClientesPage extends StatefulWidget {
  const AdminClientesPage({super.key});
  @override
  State<AdminClientesPage> createState() => _State();
}

class _State extends State<AdminClientesPage> {
  List<dynamic> _clientes = [];
  List<dynamic> _filtrados = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(ApiConstants.adminClientes);
      setState(() {
        _clientes = res.data;
        _filtrados = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar clientes';
        _loading = false;
      });
    }
  }

  void _filtrar(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtrados = q.isEmpty
          ? _clientes
          : _clientes
              .where((c) =>
                  (c['nombre'] ?? '').toLowerCase().contains(q) ||
                  (c['celular'] ?? '').contains(q) ||
                  (c['dni'] ?? '').contains(q))
              .toList();
    });
  }

  Future<void> _toggleCliente(String id, bool activo) async {
    try {
      await ApiClient().dio.patch('/admin/clientes/$id/toggle');
      _cargar();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(activo ? '🔒 Cliente desactivado' : '✅ Cliente activado'),
          backgroundColor: activo ? AppColors.naranja : AppColors.verde,
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar cliente'),
          backgroundColor: AppColors.rojo,
        ));
    }
  }

  void _verDetalle(Map<String, dynamic> cliente) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetalleClienteSheet(cliente: cliente),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stats rápidas
    final total = _clientes.length;
    final activos = _clientes.where((c) => c['activo'] == true).length;
    final inactivos = total - activos;

    return Column(children: [
      // ── Stats ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        color: AppColors.negro2,
        child: Row(children: [
          _statChip('👥 Total', '$total', AppColors.azul),
          const SizedBox(width: 8),
          _statChip('✅ Activos', '$activos', AppColors.verde),
          const SizedBox(width: 8),
          _statChip('🔒 Inactivos', '$inactivos', AppColors.naranja),
          const Spacer(),
          GestureDetector(
              onTap: _cargar,
              child:
                  const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
        ]),
      ),

      // ── Buscador ────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: AppColors.negro2,
        child: TextField(
          controller: _searchCtrl,
          onChanged: _filtrar,
          decoration: InputDecoration(
            hintText: '🔍 Buscar por nombre, celular o DNI...',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.texto2),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.texto2, size: 18),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _filtrar('');
                    },
                    child: const Icon(Icons.close,
                        color: AppColors.texto2, size: 18))
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppColors.negro3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borde)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borde)),
          ),
        ),
      ),

      // ── Lista ───────────────────────────────────────────────
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
                : _filtrados.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Text('👥', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text(
                                _searchCtrl.text.isNotEmpty
                                    ? 'No se encontraron clientes'
                                    : 'No hay clientes registrados',
                                style:
                                    const TextStyle(color: AppColors.texto2)),
                          ]))
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        color: AppColors.verde,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtrados.length,
                          itemBuilder: (_, i) => _cardCliente(_filtrados[i]),
                        ),
                      ),
      ),
    ]);
  }

  Widget _cardCliente(Map<String, dynamic> c) {
    final activo = c['activo'] == true;
    final nombre = c['nombre'] ?? '—';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _verDetalle(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: activo
                  ? AppColors.borde
                  : AppColors.naranja.withOpacity(0.3)),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activo
                  ? AppColors.verde.withOpacity(0.15)
                  : AppColors.naranja.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(inicial,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: activo ? AppColors.verde : AppColors.naranja))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(nombre,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  if (!activo)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.naranja.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('INACTIVO',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.naranja,
                                fontWeight: FontWeight.w700))),
                ]),
                Text('+51 ${c['celular'] ?? ''}',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.texto2)),
                if (c['dni'] != null)
                  Text('DNI: ${c['dni']}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.texto2)),
              ])),
          // Stats
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${c['total_reservas'] ?? 0} reservas',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
            Text('S/.${(c['total_gastado'] ?? 0.0).toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.verde)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios,
              color: AppColors.texto2, size: 12),
        ]),
      ),
    );
  }

  Widget _statChip(String label, String valor, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
        ]),
      );
}

// ── DETALLE DEL CLIENTE ──────────────────────────────────────
class _DetalleClienteSheet extends StatelessWidget {
  final Map<String, dynamic> cliente;
  const _DetalleClienteSheet({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final activo = cliente['activo'] == true;
    final nombre = cliente['nombre'] ?? '—';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.borde,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        // Avatar grande
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: activo
                  ? AppColors.verde.withOpacity(0.15)
                  : AppColors.naranja.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: activo ? AppColors.verde : AppColors.naranja,
                  width: 2)),
          child: Center(
              child: Text(inicial,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: activo ? AppColors.verde : AppColors.naranja))),
        ),
        const SizedBox(height: 10),
        Text(nombre,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        Text(activo ? '✅ Activo' : '🔒 Inactivo',
            style: TextStyle(
                fontSize: 12,
                color: activo ? AppColors.verde : AppColors.naranja)),

        const SizedBox(height: 16),
        const Divider(color: AppColors.borde),
        const SizedBox(height: 10),

        // Datos
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borde),
          ),
          child: Column(children: [
            _fila('📱 Celular', '+51 ${cliente['celular'] ?? '—'}'),
            _fila('🪪 DNI', cliente['dni'] ?? '—'),
            _fila('📋 Reservas', '${cliente['total_reservas'] ?? 0}'),
            _fila('💰 Total gastado',
                'S/.${(cliente['total_gastado'] ?? 0.0).toStringAsFixed(2)}'),
          ]),
        ),
        const SizedBox(height: 16),

        // Botón activar/desactivar
        SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                Navigator.pop(context);
                await ApiClient()
                    .dio
                    .patch('/admin/clientes/${cliente['id']}/toggle');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: activo ? AppColors.naranja : AppColors.verde,
                side: BorderSide(
                    color: activo ? AppColors.naranja : AppColors.verde),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                  activo ? '🔒 Desactivar cliente' : '✅ Activar cliente',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            )),
        const SizedBox(height: 8),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar',
                style: TextStyle(color: AppColors.texto2))),
      ]),
    );
  }

  Widget _fila(String label, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label,
              style: const TextStyle(color: AppColors.texto2, fontSize: 13)),
          const Spacer(),
          Text(valor,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}
