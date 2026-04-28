import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:dio/dio.dart';

class AdminSuscripcionPage extends StatefulWidget {
  const AdminSuscripcionPage({super.key});
  @override
  State<AdminSuscripcionPage> createState() => _State();
}

class _State extends State<AdminSuscripcionPage> {
  List<dynamic> _planes = [];
  Map<String, dynamic>? _suscripcion;
  String  _yapeNumero    = '';
  String? _qrBase64;
  String? _cuentaBcp;
  String? _cuentaBbva;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient().dio.get('/suscripcion/planes'),
        ApiClient().dio.get('/suscripcion/mi-suscripcion'),
      ]);
      final planesData = results[0].data as Map<String, dynamic>;
      setState(() {
        _planes      = planesData['planes'] ?? [];
        _yapeNumero  = planesData['yape_numero'] ?? '';
        _qrBase64    = planesData['qr_imagen_base64'] as String?;
        _cuentaBcp   = planesData['cuenta_bcp']  as String?;
        _cuentaBbva  = planesData['cuenta_bbva'] as String?;
        _suscripcion = results[1].data;
        _loading     = false;
      });
    } catch (_) {
      setState(() { _error = 'Error al cargar suscripción'; _loading = false; });
    }
  }

  Color _planColor(String? colorKey) {
    switch (colorKey) {
      case 'verde':   return AppColors.verde;
      case 'naranja': return AppColors.naranja;
      default:        return AppColors.azul;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ],
    ));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildPlanActual(),
          const SizedBox(height: 24),
          const Text('Actualiza tu plan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Elige el plan que mejor se adapte a tu negocio',
              style: TextStyle(fontSize: 12, color: AppColors.texto2)),
          const SizedBox(height: 16),
          ..._planes.map((plan) => _buildPlanCard(plan as Map<String, dynamic>)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildPlanActual() {
    final estado    = _suscripcion?['estado'] as String?;
    final plan      = _suscripcion?['plan'] as String?;
    final diasRest  = _suscripcion?['dias_restantes'] as int?;
    final esActivo  = estado == 'activo';
    final esFree    = plan == null || plan == 'free';

    Color badgeColor;
    String badgeText;
    String planDisplay;

    if (esFree || _suscripcion == null) {
      badgeColor  = AppColors.texto2;
      badgeText   = 'GRATUITO';
      planDisplay = 'Plan Free';
    } else if (esActivo) {
      badgeColor  = AppColors.verde;
      badgeText   = 'ACTIVO';
      planDisplay = _labelPlan(plan);
    } else if (estado == 'pendiente') {
      badgeColor  = AppColors.amarillo;
      badgeText   = 'PENDIENTE';
      planDisplay = _labelPlan(plan ?? '');
    } else if (estado == 'vencido') {
      badgeColor  = AppColors.rojo;
      badgeText   = 'VENCIDO';
      planDisplay = _labelPlan(plan ?? '');
    } else {
      badgeColor  = AppColors.rojo;
      badgeText   = 'RECHAZADO';
      planDisplay = _labelPlan(plan ?? '');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💎', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tu plan actual',
                style: TextStyle(fontSize: 11, color: AppColors.texto2, letterSpacing: 1)),
            Text(planDisplay,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withOpacity(0.5)),
            ),
            child: Text(badgeText,
                style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ]),
        if (esFree || _suscripcion == null) ...[
          const SizedBox(height: 10),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 10),
          const Text('⚠️  Máximo 2 canchas  •  Sin facturación electrónica',
              style: TextStyle(fontSize: 11, color: AppColors.texto2)),
        ] else if (esActivo && diasRest != null) ...[
          const SizedBox(height: 10),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today, size: 13, color: AppColors.texto2),
            const SizedBox(width: 6),
            Text('Vence en $diasRest día${diasRest != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          ]),
        ] else if (estado == 'pendiente') ...[
          const SizedBox(height: 10),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 10),
          const Text('⏳  Tu voucher está en revisión. El super admin lo verificará pronto.',
              style: TextStyle(fontSize: 11, color: AppColors.amarillo)),
        ],
      ]),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final color      = _planColor(plan['color'] as String?);
    final precio     = (plan['precio'] as num).toDouble();
    final beneficios = (plan['beneficios'] as List).cast<String>();

    return GestureDetector(
      onTap: () => _mostrarDialogoPago(plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(plan['nombre'] as String,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ),
            const Spacer(),
            RichText(text: TextSpan(children: [
              TextSpan(text: 'S/.', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
              TextSpan(text: '${precio.toStringAsFixed(0)}', style: TextStyle(fontSize: 26, color: color, fontWeight: FontWeight.w900)),
              const TextSpan(text: '/mes', style: TextStyle(fontSize: 11, color: AppColors.texto2)),
            ])),
          ]),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 12),
          ...beneficios.take(3).map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(b, style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
          )),
          if (beneficios.length > 3)
            Text('+ ${beneficios.length - 3} beneficios más',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _mostrarDialogoPago(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: AppColors.negro,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('SUSCRIBIRME', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }

  void _mostrarDialogoPago(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PagoSheet(
        plan: plan,
        yapeNumero: _yapeNumero,
        qrBase64:   _qrBase64,
        cuentaBcp:  _cuentaBcp,
        cuentaBbva: _cuentaBbva,
        onPagoConfirmado: () {
          Navigator.pop(context);
          _cargar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Voucher enviado — el super admin lo verificará pronto'),
            backgroundColor: AppColors.verde,
          ));
        },
      ),
    );
  }

  String _labelPlan(String p) {
    switch (p) {
      case 'boleta':   return 'Plan Boleta';
      case 'factura':  return 'Plan Factura';
      case 'completo': return 'Plan Completo';
      case 'basico':   return 'Plan Básico';
      case 'premium':  return 'Plan Premium';
      default:         return 'Plan Free';
    }
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Bottom sheet de pago
// ══════════════════════════════════════════════════════════════════════════════

class _PagoSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String  yapeNumero;
  final String? qrBase64;
  final String? cuentaBcp;
  final String? cuentaBbva;
  final VoidCallback onPagoConfirmado;

  const _PagoSheet({
    required this.plan,
    required this.yapeNumero,
    this.qrBase64,
    this.cuentaBcp,
    this.cuentaBbva,
    required this.onPagoConfirmado,
  });

  @override
  State<_PagoSheet> createState() => _PagoSheetState();
}

class _PagoSheetState extends State<_PagoSheet> {
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  bool _enviando = false;
  int _tab = 0; // 0=beneficios, 1=pago

  Color get _color {
    switch (widget.plan['color'] as String?) {
      case 'verde':   return AppColors.verde;
      case 'naranja': return AppColors.naranja;
      default:        return AppColors.azul;
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagenBytes  = bytes;
      _imagenNombre = picked.name;
    });
  }

  Future<void> _confirmarPago() async {
    if (_imagenBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Debes subir la captura del pago'),
        backgroundColor: AppColors.rojo,
      ));
      return;
    }

    setState(() => _enviando = true);
    try {
      // 1. Crear registro de suscripción pendiente
      final pagoRes = await ApiClient().dio.post('/suscripcion/pagar', data: {
        'plan': widget.plan['id'],
        'metodo_pago': 'yape',
      });
      final suscripcionId = pagoRes.data['id'] as String;

      // 2. Subir voucher
      final formData = FormData.fromMap({
        'imagen': MultipartFile.fromBytes(
          _imagenBytes!,
          filename: _imagenNombre ?? 'voucher.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });
      await ApiClient().dio.post('/suscripcion/$suscripcionId/voucher', data: formData);

      widget.onPagoConfirmado();
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'Error al enviar el pago. Intenta de nuevo.';
      final status = e.response?.statusCode;
      if (status == 409) {
        msg = 'Ya tienes un pago pendiente. El super admin lo verificará pronto.';
      } else if (status == 503) {
        msg = 'Servicio de imágenes no disponible. Intenta más tarde.';
      } else if (e.response?.data?['detail'] != null) {
        msg = e.response!.data['detail'].toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.rojo,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al enviar el pago. Intenta de nuevo.'),
          backgroundColor: AppColors.rojo,
        ));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final precio     = (widget.plan['precio'] as num).toDouble();
    final beneficios = (widget.plan['beneficios'] as List).cast<String>();
    final nombre     = widget.plan['nombre'] as String;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _color)),
                Text('S/.${precio.toStringAsFixed(0)} / mes',
                    style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
              ])),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.texto2),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _tabBtn('Beneficios', 0),
              const SizedBox(width: 8),
              _tabBtn('Realizar Pago', 1),
            ]),
          ),

          const Divider(color: AppColors.borde, height: 1),

          // Content
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: _tab == 0
                  ? _buildBeneficios(beneficios)
                  : _buildPago(precio),
            ),
          ),

          // Botón confirmar (solo en tab pago)
          if (_tab == 1)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16,
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _confirmarPago,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: AppColors.negro,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _enviando
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                      : const Text('CONFIRMAR PAGO', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _tabBtn(String label, int idx) => GestureDetector(
    onTap: () => setState(() => _tab = idx),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: _tab == idx ? _color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _tab == idx ? _color : AppColors.borde),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _tab == idx ? _color : AppColors.texto2,
      )),
    ),
  );

  List<Widget> _buildBeneficios(List<String> beneficios) => [
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Incluye en este plan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _color)),
        const SizedBox(height: 12),
        ...beneficios.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(b, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.3)),
        )),
      ]),
    ),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.negro3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('💡  Plan Free (sin costo)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.texto2)),
        SizedBox(height: 8),
        Text('❌  Máximo 2 canchas', style: TextStyle(fontSize: 12, color: AppColors.texto2)),
        SizedBox(height: 4),
        Text('❌  Sin boletas electrónicas', style: TextStyle(fontSize: 12, color: AppColors.texto2)),
        SizedBox(height: 4),
        Text('❌  Sin facturas electrónicas', style: TextStyle(fontSize: 12, color: AppColors.texto2)),
      ]),
    ),
    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => setState(() => _tab = 1),
        style: ElevatedButton.styleFrom(
          backgroundColor: _color,
          foregroundColor: AppColors.negro,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('CONTINUAR AL PAGO →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ),
    ),
  ];

  List<Widget> _buildPago(double precio) {
    final numero = widget.yapeNumero.isNotEmpty ? widget.yapeNumero : 'No configurado';

    // Decode QR if present
    Uint8List? qrBytes;
    final qr = widget.qrBase64;
    if (qr != null && qr.isNotEmpty) {
      try {
        qrBytes = base64Decode(qr.contains(',') ? qr.split(',').last : qr);
      } catch (_) {}
    }

    return [
      // Card Yape número
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C1FC9), Color(0xFF8B2BE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('📱 YAPE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Número para yapear', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            numero,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4),
          ),
          // QR image
          if (qrBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(qrBytes, width: 150, height: 150, fit: BoxFit.contain),
            ),
            const SizedBox(height: 6),
            const Text('Escanea el QR para pagar',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('S/.${precio.toStringAsFixed(0)}.00',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      const SizedBox(height: 8),

      // Botón copiar número
      if (widget.yapeNumero.isNotEmpty)
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.yapeNumero));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('📋 Número copiado al portapapeles'),
              duration: Duration(seconds: 2),
              backgroundColor: AppColors.verde,
            ));
          },
          icon: const Icon(Icons.copy, size: 14, color: AppColors.texto2),
          label: const Text('Copiar número', style: TextStyle(color: AppColors.texto2, fontSize: 12)),
        ),

      // Cuentas bancarias
      if ((widget.cuentaBcp?.isNotEmpty ?? false) || (widget.cuentaBbva?.isNotEmpty ?? false)) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borde),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🏦 También puedes transferir',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.texto2)),
            const SizedBox(height: 10),
            if (widget.cuentaBcp?.isNotEmpty ?? false) ...[
              const Text('BCP', style: TextStyle(fontSize: 11, color: AppColors.texto2)),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(widget.cuentaBcp!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.cuentaBcp!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('📋 Cuenta BCP copiada'), duration: Duration(seconds: 2),
                      backgroundColor: AppColors.verde,
                    ));
                  },
                  child: const Icon(Icons.copy, size: 14, color: AppColors.texto2),
                ),
              ]),
              const SizedBox(height: 8),
            ],
            if (widget.cuentaBbva?.isNotEmpty ?? false) ...[
              const Text('BBVA', style: TextStyle(fontSize: 11, color: AppColors.texto2)),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(widget.cuentaBbva!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.cuentaBbva!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('📋 Cuenta BBVA copiada'), duration: Duration(seconds: 2),
                      backgroundColor: AppColors.verde,
                    ));
                  },
                  child: const Icon(Icons.copy, size: 14, color: AppColors.texto2),
                ),
              ]),
            ],
          ]),
        ),
      ],

      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.amarillo.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.amarillo.withOpacity(0.3)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('⚠️', style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Yapea o transfiere exactamente el monto indicado.\nPon como concepto: "Suscripción PichangaYa"',
            style: TextStyle(fontSize: 11, color: AppColors.amarillo, height: 1.5),
          )),
        ]),
      ),
      const SizedBox(height: 20),

      // Upload voucher
      const Text('Sube tu captura de pago',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _seleccionarImagen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _imagenBytes != null ? null : 110,
          decoration: BoxDecoration(
            color: _imagenBytes != null ? Colors.transparent : AppColors.negro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _imagenBytes != null ? _color : AppColors.borde,
              width: _imagenBytes != null ? 1.5 : 1,
            ),
          ),
          child: _imagenBytes != null
              ? Stack(alignment: Alignment.topRight, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(_imagenBytes!, fit: BoxFit.contain),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _imagenBytes = null; _imagenNombre = null; }),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.negro, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ])
              : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.upload_rounded, size: 32, color: _color.withOpacity(0.7)),
                  const SizedBox(height: 8),
                  Text('Toca para seleccionar imagen',
                      style: TextStyle(fontSize: 12, color: _color.withOpacity(0.8))),
                  const Text('JPG, PNG — máx. 5MB',
                      style: TextStyle(fontSize: 10, color: AppColors.texto2)),
                ])),
        ),
      ),
      const SizedBox(height: 12),

      if (_imagenBytes != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.verde.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.verde.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.check_circle_outline, color: AppColors.verde, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Imagen lista. Presiona "CONFIRMAR PAGO" para enviar.',
              style: TextStyle(fontSize: 11, color: AppColors.verde),
            )),
          ]),
        ),
      const SizedBox(height: 80),
    ];
  }
}
