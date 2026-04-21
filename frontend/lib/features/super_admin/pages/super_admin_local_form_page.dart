import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class SuperAdminLocalFormPage extends StatefulWidget {
  final VoidCallback onLocalCreado;
  const SuperAdminLocalFormPage({super.key, required this.onLocalCreado});

  @override
  State<SuperAdminLocalFormPage> createState() => _State();
}

class _State extends State<SuperAdminLocalFormPage> {
  final _formKey     = GlobalKey<FormState>();
  final _nombreCtrl  = TextEditingController();
  final _dirCtrl     = TextEditingController();
  final _latCtrl     = TextEditingController();
  final _lngCtrl     = TextEditingController();
  final _telCtrl     = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _precioCtrl  = TextEditingController();

  List<dynamic> _admins = [];
  String? _adminIdSeleccionado;
  bool _activo = true;
  bool _loading = false;
  bool _loadingAdmins = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarAdmins();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _dirCtrl.dispose(); _latCtrl.dispose();
    _lngCtrl.dispose(); _telCtrl.dispose(); _descCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAdmins() async {
    try {
      final res = await ApiClient().dio.get('/super-admin/admins');
      setState(() {
        _admins = (res.data as List? ?? []).where((a) => a['activo'] == true).toList();
        _loadingAdmins = false;
      });
    } catch (_) {
      setState(() => _loadingAdmins = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_adminIdSeleccionado == null) {
      setState(() => _error = 'Selecciona un admin');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      await ApiClient().dio.post('/super-admin/locales', data: {
        'admin_id':    _adminIdSeleccionado,
        'nombre':      _nombreCtrl.text.trim(),
        'direccion':   _dirCtrl.text.trim(),
        'lat':         double.parse(_latCtrl.text.trim()),
        'lng':         double.parse(_lngCtrl.text.trim()),
        'telefono':    _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'precio_desde': _precioCtrl.text.trim().isEmpty ? 0.0 : double.parse(_precioCtrl.text.trim()),
        'activo':      _activo,
      });
      widget.onLocalCreado();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Local creado exitosamente'),
          backgroundColor: AppColors.verde,
        ));
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ?? e.message ?? 'Error desconocido';
      setState(() { _error = msg; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        backgroundColor: AppColors.negro2,
        title: const Text('Nuevo Local', style: TextStyle(color: AppColors.texto)),
        iconTheme: const IconThemeData(color: AppColors.texto),
      ),
      body: _loadingAdmins
          ? const Center(child: CircularProgressIndicator(color: AppColors.amarillo))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Dropdown Admin
                  DropdownButtonFormField<String>(
                    value: _adminIdSeleccionado,
                    dropdownColor: AppColors.negro2,
                    style: const TextStyle(color: AppColors.texto),
                    decoration: _inputDeco('Admin asignado', 'Seleccionar admin'),
                    items: _admins.map<DropdownMenuItem<String>>((a) {
                      return DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text('${a['nombre']} · ${a['celular']}',
                            style: const TextStyle(color: AppColors.texto, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _adminIdSeleccionado = v),
                    validator: (v) => v == null ? 'Selecciona un admin' : null,
                  ),
                  const SizedBox(height: 16),
                  _campo(_nombreCtrl, 'Nombre del local', 'Ej: Canchas El Crack',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                  const SizedBox(height: 16),
                  _campo(_dirCtrl, 'Dirección', 'Ej: Av. Túpac Amaru 1234, Comas',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _campo(_latCtrl, 'Latitud', '-11.9320',
                        keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (double.tryParse(v.trim()) == null) return 'Número inválido';
                          return null;
                        })),
                    const SizedBox(width: 12),
                    Expanded(child: _campo(_lngCtrl, 'Longitud', '-77.0513',
                        keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (double.tryParse(v.trim()) == null) return 'Número inválido';
                          return null;
                        })),
                  ]),
                  const SizedBox(height: 16),
                  _campo(_telCtrl, 'Teléfono (opcional)', 'Ej: 955123456',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _campo(_descCtrl, 'Descripción (opcional)', 'Ej: 3 canchas techadas, estacionamiento',
                      maxLines: 2),
                  const SizedBox(height: 16),
                  _campo(_precioCtrl, 'Precio desde (S/)', 'Ej: 80.0',
                      keyboardType: TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 16),
                  // Switch activo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.negro3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borde),
                    ),
                    child: Row(children: [
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Visible en el mapa', style: TextStyle(color: AppColors.texto, fontSize: 14)),
                        Text('Los clientes podrán ver este local', style: TextStyle(color: AppColors.texto2, fontSize: 12)),
                      ])),
                      Switch(
                        value: _activo,
                        onChanged: (v) => setState(() => _activo = v),
                        activeColor: AppColors.verde,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.rojo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.rojo.withOpacity(0.5)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
                    ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verde,
                        foregroundColor: AppColors.negro,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                          : const Text('Crear Local', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.texto),
        decoration: _inputDeco(label, hint),
        validator: validator,
      );

  InputDecoration _inputDeco(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: AppColors.texto2),
    hintStyle: TextStyle(color: AppColors.texto2.withOpacity(0.5)),
    filled: true,
    fillColor: AppColors.negro3,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borde)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borde)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.verde, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.rojo)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.rojo, width: 1.5)),
  );
}
