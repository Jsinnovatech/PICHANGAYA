import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class AddCanchaModal extends StatefulWidget {
  final VoidCallback onSuccess;
  const AddCanchaModal({super.key, required this.onSuccess});
  @override
  State<AddCanchaModal> createState() => _State();
}

class _State extends State<AddCanchaModal> {
  final _nombreCtrl     = TextEditingController();
  final _capacidadCtrl  = TextEditingController(text: '10');
  final _precioCtrl     = TextEditingController();
  final _descCtrl       = TextEditingController();

  List<dynamic> _locales = [];
  String? _localId;
  String _superficie = 'Gras Sintético';
  bool _loading = false;
  bool _loadingLocales = true;
  String? _error;

  static const _superficies = ['Gras Sintético', 'Piso Madera', 'Cemento', 'Parquet'];

  @override
  void initState() {
    super.initState();
    _cargarLocales();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _capacidadCtrl.dispose();
    _precioCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarLocales() async {
    try {
      final res = await ApiClient().dio.get('/locales');
      setState(() { _locales = res.data; _loadingLocales = false; });
    } catch (_) {
      setState(() => _loadingLocales = false);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final precio = double.tryParse(_precioCtrl.text.trim());
    final capacidad = int.tryParse(_capacidadCtrl.text.trim());

    if (nombre.isEmpty) { setState(() => _error = 'Ingresa el nombre'); return; }
    if (_localId == null) { setState(() => _error = 'Selecciona un local'); return; }
    if (precio == null || precio <= 0) { setState(() => _error = 'Ingresa un precio válido'); return; }
    if (capacidad == null || capacidad <= 0) { setState(() => _error = 'Ingresa una capacidad válida'); return; }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient().dio.post('/admin/canchas', data: {
        'nombre': nombre,
        'local_id': _localId,
        'capacidad': capacidad,
        'precio_hora': precio,
        'superficie': _superficie,
        if (_descCtrl.text.trim().isNotEmpty) 'descripcion': _descCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Cancha creada correctamente'),
          backgroundColor: AppColors.verde,
        ));
      }
    } catch (e) {
      setState(() { _error = 'Error al crear cancha'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Handle
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('🏟️ Nueva Cancha', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 20),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.rojo.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.rojo.withOpacity(0.4))),
              child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],

          _label('NOMBRE DE LA CANCHA'),
          TextField(controller: _nombreCtrl, decoration: const InputDecoration(hintText: 'Ej: Cancha A')),
          const SizedBox(height: 14),

          _label('LOCAL'),
          _loadingLocales
              ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.verde)))
              : DropdownButtonFormField<String>(
                  value: _localId,
                  dropdownColor: AppColors.negro3,
                  hint: const Text('Seleccionar local', style: TextStyle(color: AppColors.texto2, fontSize: 14)),
                  items: _locales.map<DropdownMenuItem<String>>((l) => DropdownMenuItem(
                    value: l['id'].toString(),
                    child: Text(l['nombre'] ?? '—', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  )).toList(),
                  onChanged: (v) => setState(() => _localId = v),
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.negro3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borde)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borde)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('CAPACIDAD'),
              TextField(controller: _capacidadCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '10')),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('PRECIO/HORA (S/.)'),
              TextField(controller: _precioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '70.00')),
            ])),
          ]),
          const SizedBox(height: 14),

          _label('SUPERFICIE'),
          DropdownButtonFormField<String>(
            value: _superficie,
            dropdownColor: AppColors.negro3,
            items: _superficies.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
            onChanged: (v) => setState(() => _superficie = v!),
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.negro3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borde)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borde)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          _label('DESCRIPCIÓN (opcional)'),
          TextField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Descripción adicional...')),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _loading ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde, foregroundColor: AppColors.negro,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                : const Text('✅ CREAR CANCHA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppColors.texto2))),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.texto2, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
  );
}
