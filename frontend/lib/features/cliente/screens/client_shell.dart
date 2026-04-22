import 'package:pichangaya/core/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/shared/models/local_model.dart';
import 'package:pichangaya/features/cliente/tabs/mapa_tab.dart';
import 'package:pichangaya/features/cliente/tabs/canchas_tab.dart';
import 'package:pichangaya/features/cliente/tabs/pagar_tab.dart';
import 'package:pichangaya/features/cliente/tabs/mis_reservas_tab.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});
  @override
  State<ClientShell> createState() => _State();
}

class _State extends State<ClientShell> {
  int _tabIndex = 0;
  LocalModel? _localSeleccionado;
  String _nombreCliente  = '';
  String _celularCliente = '';
  String _dniCliente     = '';

  @override
  void initState() {
    super.initState();
    _cargarNombre();
    // Registrar FCM token ahora que el JWT ya está disponible
    FcmService.instance.syncToken();
  }

  Future<void> _cargarNombre() async {
    try {
      final res = await ApiClient().dio.get('/auth/me');
      if (mounted) {
        setState(() {
          final nombre   = (res.data['nombre']  ?? '').toString();
          final celular  = (res.data['celular'] ?? '').toString();
          final dni      = (res.data['dni']     ?? '').toString();
          _nombreCliente  = nombre.split(' ').first;
          _celularCliente = celular;
          _dniCliente     = dni;
        });
      }
    } catch (_) {}
  }

  void _goTab(int i) => setState(() {
        _tabIndex = i;
      });

  void _onLocalSeleccionado(LocalModel? local) {
    setState(() {
      _localSeleccionado = local;
      _tabIndex = 1; // ir a CanchasTab
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabWidgets = [
      MapaTab(onLocalSeleccionado: _onLocalSeleccionado),
      CanchasTab(
        localFiltro:     _localSeleccionado,
        nombreCliente:   _nombreCliente,
        celularCliente:  _celularCliente,
        dniCliente:      _dniCliente,
      ),
      const PagarTab(),
      const MisReservasTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.negro,
      // ── TopBar minimalista ──────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.negro2,
        elevation: 0,
        titleSpacing: 16,
        title: Text('⚽ PICHANGAYA',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              color: AppColors.verde,
              letterSpacing: 2,
            )),
        actions: [
          // Avatar con nombre
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _mostrarMenuUsuario(context),
              child: Row(children: [
                if (_nombreCliente.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('Hola, $_nombreCliente',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.texto2,
                        )),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.verde,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.verdeOsc, width: 2),
                  ),
                  child: Center(
                      child: Text(
                    _nombreCliente.isNotEmpty
                        ? _nombreCliente[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.negro,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  )),
                ),
              ]),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borde),
        ),
      ),

      // ── Contenido ───────────────────────────────────────────
      body: IndexedStack(index: _tabIndex, children: tabWidgets),

      // ── Bottom Navigation Bar — mobile-first ────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(top: BorderSide(color: AppColors.borde)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(children: [
              _navItem(0, Icons.map_outlined, Icons.map, 'Cerca'),
              _navItem(1, Icons.sports_soccer_outlined, Icons.sports_soccer,
                  'Canchas'),
              _navItem(2, Icons.payment_outlined, Icons.payment, 'Pagar'),
              _navItem(3, Icons.receipt_long_outlined, Icons.receipt_long,
                  'Reservas'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData iconOff, IconData iconOn, String label) {
    final activo = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge en Pagar si hay pagos pendientes
            Icon(
              activo ? iconOn : iconOff,
              color: activo ? AppColors.verde : AppColors.texto2,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: activo ? AppColors.verde : AppColors.texto2,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
                )),
            // Indicador activo
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: activo ? 20 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.verde,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarMenuUsuario(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
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
            const SizedBox(height: 20),
            // Avatar grande
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.verde,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.verdeOsc, width: 3),
              ),
              child: Center(
                  child: Text(
                _nombreCliente.isNotEmpty
                    ? _nombreCliente[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.negro,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              )),
            ),
            const SizedBox(height: 10),
            Text(_nombreCliente.isNotEmpty ? _nombreCliente : 'Cliente',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
            const SizedBox(height: 4),
            const Text('Cliente PichangaYa',
                style: TextStyle(fontSize: 13, color: AppColors.texto2)),
            const SizedBox(height: 20),
            const Divider(color: AppColors.borde),
            const SizedBox(height: 10),
            // Mis reservas
            _menuItem(
              icon: Icons.receipt_long,
              label: 'Mis Reservas',
              onTap: () {
                Navigator.pop(context);
                _goTab(3);
              },
            ),
            const SizedBox(height: 8),
            // Editar perfil
            _menuItem(
              icon: Icons.edit_outlined,
              label: 'Editar Perfil',
              onTap: () {
                Navigator.pop(context);
                _abrirEditarPerfil(context);
              },
            ),
            const SizedBox(height: 8),
            // Cerrar sesión
            _menuItem(
              icon: Icons.logout,
              label: 'Cerrar Sesión',
              color: AppColors.rojo,
              onTap: () async {
                Navigator.pop(context);
                await FcmService.instance.limpiarToken();
                await ApiClient().logout();
                if (mounted) context.go('/entry');
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _abrirEditarPerfil(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditarPerfilSheet(
        nombreInicial:  _nombreCliente,
        celular:        _celularCliente,
        dniInicial:     _dniCliente,
        onGuardado: (nombre, dni) {
          setState(() {
            _nombreCliente = nombre.split(' ').first;
            _dniCliente    = dni;
          });
        },
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.texto2,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  color: color,
                  fontWeight: FontWeight.w500,
                )),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                color: color.withOpacity(0.5), size: 14),
          ]),
        ),
      );
}

// ── Formulario edición de perfil ─────────────────────────────────────────────

class _EditarPerfilSheet extends StatefulWidget {
  final String nombreInicial;
  final String celular;
  final String dniInicial;
  final void Function(String nombre, String dni) onGuardado;

  const _EditarPerfilSheet({
    required this.nombreInicial,
    required this.celular,
    required this.dniInicial,
    required this.onGuardado,
  });

  @override
  State<_EditarPerfilSheet> createState() => _EditarPerfilSheetState();
}

class _EditarPerfilSheetState extends State<_EditarPerfilSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _email;
  late final TextEditingController _dni;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.nombreInicial);
    _email  = TextEditingController();
    _dni    = TextEditingController(text: widget.dniInicial);
    // Cargar email actual desde /auth/me
    ApiClient().dio.get('/auth/me').then((res) {
      if (mounted) _email.text = res.data['email'] ?? '';
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nombre.dispose(); _email.dispose(); _dni.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final data = <String, dynamic>{};
    if (_nombre.text.trim().isNotEmpty) data['nombre'] = _nombre.text.trim();
    if (_email.text.trim().isNotEmpty)  data['email']  = _email.text.trim();
    data['dni'] = _dni.text.trim();

    try {
      await ApiClient().dio.patch('/auth/me', data: data);
      widget.onGuardado(_nombre.text.trim(), _dni.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Perfil actualizado'),
          backgroundColor: Color(0xFF1B5E20),
        ));
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        String msg = 'Error al guardar';
        if (e.toString().contains('400')) msg = 'El correo ya está en uso';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.rojo,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('✏️ Editar Perfil',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: AppColors.texto2, size: 22),
              ),
            ]),
            const SizedBox(height: 8),
            // Celular (solo lectura)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.negro,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: Row(children: [
                const Icon(Icons.phone, color: AppColors.texto2, size: 16),
                const SizedBox(width: 8),
                Text(widget.celular,
                    style: const TextStyle(color: AppColors.texto2, fontSize: 14)),
                const SizedBox(width: 8),
                const Text('(no editable)',
                    style: TextStyle(color: AppColors.borde, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 12),
            _campo(_nombre, 'Nombre completo *', required: true),
            const SizedBox(height: 12),
            _campo(_email, 'Correo electrónico', tipo: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _campo(_dni, 'DNI', tipo: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _guardando
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar cambios',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {
    bool required = false,
    TextInputType tipo = TextInputType.text,
  }) =>
    TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.texto2, fontSize: 13),
        filled: true,
        fillColor: AppColors.negro,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borde)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borde)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.verde, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
}
