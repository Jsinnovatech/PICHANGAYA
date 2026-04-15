import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminPlanesPage extends StatefulWidget {
  const SuperAdminPlanesPage({super.key});
  @override
  State<SuperAdminPlanesPage> createState() => _State();
}

class _State extends State<SuperAdminPlanesPage> {
  List<dynamic> _planes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(ApiConstants.superAdminPlanes);
      setState(() { _planes = res.data; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error al cargar planes'; _loading = false; });
    }
  }

  void _editarPlan(Map<String, dynamic> plan) {
    final nombreCtrl = TextEditingController(text: plan['nombre'] ?? '');
    final precioCtrl = TextEditingController(text: plan['precio']?.toString() ?? '');
    final diasCtrl   = TextEditingController(text: plan['duracion_dias']?.toString() ?? '30');
    final descCtrl   = TextEditingController(text: plan['descripcion'] ?? '');
    bool activo      = plan['activo'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.negro2,
          title: Text(
            '✏️ Editar ${plan['nombre']}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campo('Nombre del plan', nombreCtrl),
              const SizedBox(height: 12),
              _campo('Precio (S/.)', precioCtrl, tipo: TextInputType.number),
              const SizedBox(height: 12),
              _campo('Duración (días)', diasCtrl, tipo: TextInputType.number),
              const SizedBox(height: 12),
              _campo('Descripción', descCtrl, maxLines: 3),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Activo', style: TextStyle(color: AppColors.texto2, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: activo,
                  onChanged: (v) => setLocal(() => activo = v),
                  activeColor: AppColors.verde,
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.texto2)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _guardar(plan['clave'], {
                  'nombre':        nombreCtrl.text.trim(),
                  'precio':        double.tryParse(precioCtrl.text) ?? plan['precio'],
                  'duracion_dias': int.tryParse(diasCtrl.text) ?? plan['duracion_dias'],
                  'descripcion':   descCtrl.text.trim(),
                  'activo':        activo,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amarillo,
                foregroundColor: AppColors.negro,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar(String clave, Map<String, dynamic> data) async {
    try {
      await ApiClient().dio.put('${ApiConstants.superAdminPlanes}/$clave', data: data);
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Plan actualizado'),
          backgroundColor: AppColors.verde,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al guardar'),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  Widget _campo(String label, TextEditingController ctrl, {
    TextInputType tipo = TextInputType.text,
    int maxLines = 1,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.texto2, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: tipo,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borde),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borde),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.amarillo),
            ),
            filled: true,
            fillColor: AppColors.negro3,
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.amarillo));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.amarillo,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _planes.length,
        itemBuilder: (_, i) {
          final p      = _planes[i] as Map<String, dynamic>;
          final activo = p['activo'] == true;
          final color  = _colorPlan(p['clave'] as String? ?? '');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: activo ? color.withOpacity(0.4) : AppColors.borde,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (p['clave'] as String).toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p['nombre'] ?? '—',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  if (!activo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.rojo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('INACTIVO',
                          style: TextStyle(fontSize: 10, color: AppColors.rojo, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _infoChip('💰 S/.${p['precio']?.toStringAsFixed(2) ?? '0.00'}', color),
                  const SizedBox(width: 8),
                  _infoChip('📅 ${p['duracion_dias']} días', AppColors.texto2),
                ]),
                if (p['descripcion'] != null && (p['descripcion'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    p['descripcion'],
                    style: const TextStyle(fontSize: 12, color: AppColors.texto2),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _editarPlan(p),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar plan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amarillo,
                      side: BorderSide(color: AppColors.amarillo.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Color _colorPlan(String clave) {
    switch (clave) {
      case 'free':     return AppColors.texto2;
      case 'boleta':   return AppColors.azul;
      case 'factura':  return AppColors.verde;
      case 'completo': return AppColors.amarillo;
      default:         return AppColors.borde;
    }
  }

  Widget _infoChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );
}
