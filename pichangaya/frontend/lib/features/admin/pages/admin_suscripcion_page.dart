import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class AdminSuscripcionPage extends StatefulWidget {
  const AdminSuscripcionPage({super.key});
  @override
  State<AdminSuscripcionPage> createState() => _AdminSuscripcionPageState();
}

class _AdminSuscripcionPageState extends State<AdminSuscripcionPage> {
  Map<String, dynamic>? _suscripcion;
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
      final res = await ApiClient().dio.get('/suscripcion/mi-suscripcion');
      setState(() {
        _suscripcion = res.data != null
            ? Map<String, dynamic>.from(res.data as Map)
            : null;
        _loading = false;
      });
    } catch (_) {
      setState(() { _suscripcion = null; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));
    }

    final estado = _suscripcion?['estado'] as String? ?? '';

    // ── SIN SUSCRIPCIÓN o VENCIDA o RECHAZADA → mostrar planes ──
    if (_suscripcion == null ||
        estado == 'vencido' ||
        estado == 'rechazado') {
      return _VistaPlanes(
        suscripcionPrevia: _suscripcion,
        onPagado: _cargar,
      );
    }

    // ── PENDIENTE → esperando verificación ──
    if (estado == 'pendiente') {
      return _VistaPendiente(
        suscripcion: _suscripcion!,
        onActualizar: _cargar,
      );
    }

    // ── ACTIVA → dashboard de suscripción ──
    return _VistaActiva(
      suscripcion: _suscripcion!,
      onRenovar: _cargar,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// VISTA — ELEGIR PLAN
// ══════════════════════════════════════════════════════════════
class _VistaPlanes extends StatefulWidget {
  final Map<String, dynamic>? suscripcionPrevia;
  final VoidCallback onPagado;
  const _VistaPlanes({this.suscripcionPrevia, required this.onPagado});
  @override
  State<_VistaPlanes> createState() => _VistaplanesState();
}

class _VistaplanesState extends State<_VistaPlanes> {
  String? _planSeleccionado;

  void _seleccionarPlan(String plan) {
    setState(() => _planSeleccionado = plan);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ModalPago(
        plan: plan,
        monto: plan == 'basico' ? 30.0 : 50.0,
        onPagado: widget.onPagado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esRenovacion = widget.suscripcionPrevia != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ── Header ────────────────────────────────────────
        if (esRenovacion && widget.suscripcionPrevia!['estado'] == 'vencido')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.naranja.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.naranja.withOpacity(0.4))),
            child: const Row(children: [
              Icon(Icons.warning_amber, color: AppColors.naranja, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                  'Tu suscripción venció. Renueva para seguir usando el sistema.',
                  style: TextStyle(
                      color: AppColors.naranja, fontSize: 13))),
            ]),
          ),

        if (esRenovacion && widget.suscripcionPrevia!['estado'] == 'rechazado')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.rojo.withOpacity(0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.cancel, color: AppColors.rojo, size: 16),
                SizedBox(width: 8),
                Text('Pago rechazado',
                    style: TextStyle(
                        color: AppColors.rojo, fontWeight: FontWeight.w700)),
              ]),
              if (widget.suscripcionPrevia!['motivo_rechazo'] != null) ...[
                const SizedBox(height: 4),
                Text('Motivo: ${widget.suscripcionPrevia!['motivo_rechazo']}',
                    style: const TextStyle(
                        color: AppColors.texto2, fontSize: 12)),
              ],
              const SizedBox(height: 6),
              const Text('Intenta nuevamente con el comprobante correcto.',
                  style: TextStyle(color: AppColors.texto2, fontSize: 12)),
            ]),
          ),

        const Text('ELIGE TU PLAN',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Accede a todas las funcionalidades de PichangaYa',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.texto2, fontSize: 13)),
        const SizedBox(height: 28),

        // ── Plan Básico ───────────────────────────────────
        _cardPlan(
          plan: 'basico',
          nombre: 'PLAN BÁSICO',
          precio: 'S/.30',
          periodo: '/mes',
          color: AppColors.verde,
          descripcion: 'Para comenzar a gestionar tu cancha',
          features: [
            '✅ Panel de reservas completo',
            '✅ Gestión de pagos y vouchers',
            '✅ Timers de partido',
            '✅ Lista de clientes',
            '🧾 Emisión de boletas simples',
            '❌ Sin facturación electrónica SUNAT',
          ],
        ),
        const SizedBox(height: 16),

        // ── Plan Premium ──────────────────────────────────
        Stack(children: [
          _cardPlan(
            plan: 'premium',
            nombre: 'PLAN PREMIUM',
            precio: 'S/.50',
            periodo: '/mes',
            color: AppColors.morado,
            descripcion: 'Para negocios que necesitan facturar',
            features: [
              '✅ Todo lo del Plan Básico',
              '✅ Facturación electrónica SUNAT',
              '✅ Emisión de boletas y facturas',
              '✅ Integración con Nubefact',
              '✅ PDF automático de comprobantes',
              '✅ Soporte prioritario',
            ],
          ),
          // Badge RECOMENDADO
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.morado,
                borderRadius: BorderRadius.circular(20)),
              child: const Text('RECOMENDADO',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.5)),
            ),
          ),
        ]),

        const SizedBox(height: 28),

        // Footer info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.negro2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borde)),
          child: const Column(children: [
            Row(children: [
              Icon(Icons.info_outline,
                  color: AppColors.texto2, size: 14),
              SizedBox(width: 8),
              Expanded(child: Text(
                  'El pago se realiza por Yape o Plin al número del administrador. Sube tu voucher y tu cuenta será activada en minutos.',
                  style: TextStyle(fontSize: 11, color: AppColors.texto2))),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _cardPlan({
    required String plan,
    required String nombre,
    required String precio,
    required String periodo,
    required Color color,
    required String descripcion,
    required List<String> features,
  }) =>
      GestureDetector(
        onTap: () => _seleccionarPlan(plan),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.negro2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.08), blurRadius: 20)
            ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nombre + precio
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: color, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(descripcion, style: const TextStyle(
                    fontSize: 11, color: AppColors.texto2)),
              ])),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(precio, style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900, color: color)),
                Text(periodo, style: const TextStyle(
                    fontSize: 12, color: AppColors.texto2,
                    fontWeight: FontWeight.w500)),
              ]),
            ]),
            const SizedBox(height: 16),
            const Divider(color: AppColors.borde, height: 1),
            const SizedBox(height: 14),

            // Features
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(f, style: const TextStyle(
                  fontSize: 12, color: AppColors.texto)),
            )).toList(),

            const SizedBox(height: 16),

            // Botón
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(
                  'Elegir $nombre ➜',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.black))),
            ),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// MODAL PAGO — Yape/Plin + subir voucher
// ══════════════════════════════════════════════════════════════
class _ModalPago extends StatefulWidget {
  final String plan;
  final double monto;
  final VoidCallback onPagado;
  const _ModalPago({
    required this.plan, required this.monto, required this.onPagado});
  @override
  State<_ModalPago> createState() => _ModalPagoState();
}

class _ModalPagoState extends State<_ModalPago> {
  String _metodo = 'yape';
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  bool _subiendo = false;
  String? _error;
  String? _suscripcionId;

  // Datos de pago del super admin
  static const _numero   = '993592328';
  static const _titular  = 'PICHANGAYA';
  static const _codigoQR = 'PYA-${_numero}'; // placeholder

  static const _metodos = [
    ('yape',          '📱 Yape',          Color(0xFF7B2FBE)),
    ('plin',          '💙 Plin',          Color(0xFF29B6F6)),
    ('transferencia', '🏦 Transferencia', Color(0xFF00E676)),
  ];

  @override
  void initState() {
    super.initState();
    _crearSuscripcion();
  }

  Future<void> _crearSuscripcion() async {
    try {
      final res = await ApiClient().dio.post('/suscripcion/pagar', data: {
        'plan': widget.plan,
        'metodo_pago': _metodo,
      });
      setState(() => _suscripcionId = res.data['id']?.toString());
    } catch (_) {}
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagenBytes = bytes;
      _imagenNombre = picked.name;
      _error = null;
    });
  }

  Future<void> _enviarVoucher() async {
    if (_imagenBytes == null) {
      setState(() => _error = 'Selecciona una captura del pago');
      return;
    }
    if (_suscripcionId == null) {
      setState(() => _error = 'Error al crear suscripción. Intenta de nuevo.');
      return;
    }
    setState(() { _subiendo = true; _error = null; });
    try {
      final formData = FormData.fromMap({
        'imagen': MultipartFile.fromBytes(
          _imagenBytes!,
          filename: _imagenNombre ?? 'voucher.jpg',
          contentType: DioMediaType('image', 'jpeg')),
      });
      await ApiClient().dio.post(
          '/suscripcion/$_suscripcionId/voucher',
          data: formData,
          options: Options(contentType: 'multipart/form-data'));

      if (mounted) {
        Navigator.pop(context);
        widget.onPagado();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Voucher enviado. Tu cuenta será activada en breve.'),
          backgroundColor: AppColors.verde,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (_) {
      setState(() {
        _error = 'Error al enviar voucher. Intenta de nuevo.';
        _subiendo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esPremium = widget.plan == 'premium';
    final colorPlan = esPremium ? AppColors.morado : AppColors.verde;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20, right: 20, top: 16),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.borde,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Título
        Row(children: [
          Text(esPremium ? '🏢 PLAN PREMIUM' : '🧾 PLAN BÁSICO',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: colorPlan, letterSpacing: 0.5)),
          const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close,
                  color: AppColors.texto2, size: 20)),
        ]),
        const SizedBox(height: 16),

        // ── Datos de pago ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorPlan.withOpacity(0.3))),
          child: Column(children: [
            // QR placeholder
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.qr_code, size: 56, color: Colors.black87),
                Text(_codigoQR,
                    style: const TextStyle(
                        fontSize: 7, color: Colors.black54)),
              ])),
            ),
            const SizedBox(height: 12),
            const Text('Envía el pago a:',
                style: TextStyle(fontSize: 12, color: AppColors.texto2)),
            const SizedBox(height: 4),
            Text(_numero,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 2)),
            Text(_titular,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.texto2)),
            const SizedBox(height: 12),
            Text('S/.${widget.monto.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w900,
                    color: colorPlan)),
            Text('Plan ${widget.plan.toUpperCase()} · 30 días',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.texto2)),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Método de pago ─────────────────────────────────
        const Align(alignment: Alignment.centerLeft,
          child: Text('MÉTODO DE PAGO', style: TextStyle(
              fontSize: 10, color: AppColors.texto2,
              letterSpacing: 0.5, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Row(children: _metodos.map((m) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _metodo = m.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _metodo == m.$1
                    ? m.$3.withOpacity(0.15) : AppColors.negro3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _metodo == m.$1 ? m.$3 : AppColors.borde,
                    width: _metodo == m.$1 ? 1.5 : 1)),
              child: Center(child: Text(m.$2,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _metodo == m.$1
                          ? m.$3 : AppColors.texto2))),
            ),
          ))).toList()),
        const SizedBox(height: 16),

        // ── Subir voucher ──────────────────────────────────
        const Align(alignment: Alignment.centerLeft,
          child: Text('SUBIR CAPTURA DEL PAGO', style: TextStyle(
              fontSize: 10, color: AppColors.texto2,
              letterSpacing: 0.5, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _seleccionarImagen,
          child: Container(
            width: double.infinity,
            height: _imagenBytes != null ? 150 : 100,
            decoration: BoxDecoration(
              color: AppColors.negro3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _imagenBytes != null
                      ? AppColors.verde : AppColors.borde)),
            child: _imagenBytes != null
              ? Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_imagenBytes!,
                          width: double.infinity, fit: BoxFit.cover)),
                  Positioned(top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _imagenBytes = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14)))),
                ])
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('📷', style: TextStyle(fontSize: 28)),
                  SizedBox(height: 6),
                  Text('Toca para subir tu captura de pago',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.texto2)),
                ]),
          ),
        ),
        const SizedBox(height: 12),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.rojo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_error!,
                style: const TextStyle(
                    color: AppColors.rojo, fontSize: 13))),
          const SizedBox(height: 10),
        ],

        // ── Botón enviar ───────────────────────────────────
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: _subiendo ? null : _enviarVoucher,
            style: ElevatedButton.styleFrom(
                backgroundColor: colorPlan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: _subiendo
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('✅ Enviar Voucher y Confirmar',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
          )),
        const SizedBox(height: 8),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// VISTA — PENDIENTE DE VERIFICACIÓN
// ══════════════════════════════════════════════════════════════
class _VistaPendiente extends StatelessWidget {
  final Map<String, dynamic> suscripcion;
  final VoidCallback onActualizar;
  const _VistaPendiente(
      {required this.suscripcion, required this.onActualizar});

  @override
  Widget build(BuildContext context) {
    final plan   = suscripcion['plan']?.toString() ?? '';
    final monto  = (suscripcion['monto'] ?? 0).toDouble();
    final metodo = suscripcion['metodo_pago']?.toString() ?? '';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Animación espera
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.amarillo.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.amarillo.withOpacity(0.4), width: 2)),
            child: const Center(child: Text('⏳',
                style: TextStyle(fontSize: 48)))),
          const SizedBox(height: 20),

          const Text('VERIFICANDO TU PAGO',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text(
              'El super administrador está revisando\ntu comprobante de pago.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.texto2, fontSize: 13)),
          const SizedBox(height: 24),

          // Info del pago
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.amarillo.withOpacity(0.3))),
            child: Column(children: [
              _fila('Plan',   plan.toUpperCase()),
              _fila('Monto',  'S/.${monto.toStringAsFixed(0)}'),
              _fila('Método', metodo.toUpperCase()),
              _fila('Estado', '⏳ PENDIENTE DE VERIFICACIÓN'),
            ]),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.verde.withOpacity(0.2))),
            child: const Column(children: [
              Row(children: [
                Icon(Icons.notifications_active,
                    color: AppColors.verde, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                    'Recibirás una notificación cuando tu cuenta sea activada.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.texto2))),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.access_time, color: AppColors.verde, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                    'El tiempo de verificación es de aproximadamente 5-30 minutos.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.texto2))),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onActualizar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Verificar estado'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.verde,
                  side: const BorderSide(color: AppColors.verde),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
        ]),
      ),
    );
  }

  Widget _fila(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text('$l:', style: const TextStyle(
            color: AppColors.texto2, fontSize: 13)),
        const Spacer(),
        Text(v, style: const TextStyle(
            color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w600)),
      ]));
}

// ══════════════════════════════════════════════════════════════
// VISTA — SUSCRIPCIÓN ACTIVA
// ══════════════════════════════════════════════════════════════
class _VistaActiva extends StatelessWidget {
  final Map<String, dynamic> suscripcion;
  final VoidCallback onRenovar;
  const _VistaActiva(
      {required this.suscripcion, required this.onRenovar});

  @override
  Widget build(BuildContext context) {
    final plan    = suscripcion['plan']?.toString() ?? '';
    final monto   = (suscripcion['monto'] ?? 0).toDouble();
    final dias    = suscripcion['dias_restantes'] as int? ?? 0;
    final vence   = suscripcion['fecha_vencimiento']?.toString() ?? '';
    final esPremium = plan == 'premium';
    final color   = esPremium ? AppColors.morado : AppColors.verde;

    // Nivel de alerta según días restantes
    final alertaColor = dias <= 3
        ? AppColors.rojo
        : dias <= 7
            ? AppColors.amarillo
            : AppColors.verde;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ── Estado activo ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4))),
          child: Column(children: [
            Text(esPremium ? '🏢' : '🧾',
                style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text('SUSCRIPCIÓN ACTIVA',
                style: TextStyle(
                    fontSize: 11, color: AppColors.verde,
                    fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Plan ${plan.toUpperCase()}',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: color)),
            Text('S/.${monto.toStringAsFixed(0)}/mes',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.texto2)),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Días restantes ─────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.negro2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: alertaColor.withOpacity(0.4))),
          child: Row(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: alertaColor.withOpacity(0.1),
                shape: BoxShape.circle),
              child: Center(child: Text('$dias',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: alertaColor))),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('días restantes',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: alertaColor)),
              Text('Vence el $vence',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.texto2)),
              if (dias <= 7)
                const Text('⚠️ Renueva pronto',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.amarillo)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Funcionalidades activas ────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.negro2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borde)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FUNCIONALIDADES INCLUIDAS',
                style: TextStyle(
                    fontSize: 10, color: AppColors.texto2,
                    letterSpacing: 0.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...(_getFeaturesActivas(plan)).map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: AppColors.verde, size: 14),
                const SizedBox(width: 8),
                Text(f, style: const TextStyle(
                    fontSize: 12, color: AppColors.texto)),
              ]),
            )).toList(),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Botón renovar anticipado ───────────────────────
        if (dias <= 7)
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRenovar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('🔄 Renovar Suscripción'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amarillo,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            )),
      ]),
    );
  }

  List<String> _getFeaturesActivas(String plan) {
    final base = [
      'Panel de reservas completo',
      'Gestión de pagos y vouchers',
      'Timers de partido en tiempo real',
      'Lista de clientes',
      'Gestión de canchas',
    ];
    if (plan == 'premium') {
      base.addAll([
        'Facturación electrónica SUNAT',
        'Emisión de boletas y facturas',
        'PDF automático de comprobantes',
      ]);
    } else {
      base.add('Emisión de boletas simples');
    }
    return base;
  }
}
