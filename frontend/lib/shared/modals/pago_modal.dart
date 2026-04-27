import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

/// Modal Paso 2 — instrucciones de pago y subida de voucher.
///
/// Parámetros:
/// - [pagoId]         ID del pago creado por el backend
/// - [monto]          Monto a pagar (en soles)
/// - [metodoPago]     yape | plin | transferencia | efectivo | tarjeta
/// - [canchaName]     Nombre de la cancha (para el encabezado)
/// - [localId]        ID del local (para obtener medios de pago del admin)
/// - [onVoucherSubido] Callback al completar el flujo
class PagoModal extends StatefulWidget {
  final String pagoId;
  final double monto;
  final String metodoPago;
  final String canchaName;
  final String? localId;
  final VoidCallback onVoucherSubido;

  const PagoModal({
    super.key,
    required this.pagoId,
    required this.monto,
    required this.metodoPago,
    required this.canchaName,
    this.localId,
    required this.onVoucherSubido,
  });

  /// Abre el modal como bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String pagoId,
    required double monto,
    required String metodoPago,
    required String canchaName,
    String? localId,
    required VoidCallback onVoucherSubido,
  }) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => PagoModal(
          pagoId: pagoId,
          monto: monto,
          metodoPago: metodoPago,
          canchaName: canchaName,
          localId: localId,
          onVoucherSubido: onVoucherSubido,
        ),
      );

  @override
  State<PagoModal> createState() => _PagoModalState();
}

class _PagoModalState extends State<PagoModal> {
  // ── Estado del voucher ────────────────────────────────────────
  File?      _imageFile;
  Uint8List? _imageBytes;
  String?    _imageName;

  bool    _uploading = false;
  String? _error;

  // ── Datos de pago cargados desde el backend ───────────────────
  Map<String, Map<String, String>> _datosPago = {
    'yape':          {'numero': 'Cargando...', 'titular': '', 'icono': '📱'},
    'plin':          {'numero': 'Cargando...', 'titular': '', 'icono': '💙'},
    'transferencia': {'numero': 'Cargando...', 'titular': '', 'icono': '🏦'},
    'efectivo':      {'numero': 'Paga en el local', 'titular': 'Al momento de jugar', 'icono': '💵'},
    'tarjeta':       {'numero': 'En el local',      'titular': 'Al momento de jugar', 'icono': '💳'},
  };
  String? _qrBase64;   // imagen QR del admin (base64 data URL o URL directa)

  @override
  void initState() {
    super.initState();
    _cargarDatosPago();
  }

  Future<void> _cargarDatosPago() async {
    try {
      // Usa el endpoint por local si tenemos localId, sino el global legacy
      final endpoint = (widget.localId != null && widget.localId!.isNotEmpty)
          ? '/locales/${widget.localId}/medios-pago'
          : '/locales/configuracion/pagos';

      final res = await ApiClient().dio.get(endpoint);
      final d = res.data as Map<String, dynamic>;

      // Campos del nuevo endpoint (/locales/{id}/medios-pago)
      final yape    = d['yape_numero']?.toString()      ?? '';
      final bcp     = d['cuenta_bcp']?.toString()       ?? '';
      final bbva    = d['cuenta_bbva']?.toString()      ?? '';
      final qr      = d['qr_imagen_base64']?.toString();
      // Campos del endpoint legacy (/locales/configuracion/pagos)
      final titular = d['titular']?.toString()          ?? '';

      // Para transferencia: mostrar BCP y/o BBVA
      String cuentas = '';
      if (bcp.isNotEmpty && bbva.isNotEmpty) {
        cuentas = 'BCP: $bcp\nBBVA: $bbva';
      } else if (bcp.isNotEmpty) {
        cuentas = 'BCP: $bcp';
      } else if (bbva.isNotEmpty) {
        cuentas = 'BBVA: $bbva';
      }

      if (mounted) {
        setState(() {
          _qrBase64 = qr;
          _datosPago = {
            'yape':          {'numero': yape.isNotEmpty ? yape : '—', 'titular': titular, 'icono': '📱'},
            'plin':          {'numero': yape.isNotEmpty ? yape : '—', 'titular': titular, 'icono': '💙'},
            'transferencia': {'numero': cuentas.isNotEmpty ? cuentas : '—', 'titular': titular, 'icono': '🏦'},
            'efectivo':      {'numero': 'Paga en el local', 'titular': 'Al momento de jugar', 'icono': '💵'},
            'tarjeta':       {'numero': 'En el local',      'titular': 'Al momento de jugar', 'icono': '💳'},
          };
        });
      }
    } catch (e) {
      debugPrint('[PagoModal] No se pudieron cargar datos de pago: $e');
    }
  }

  // ── Selección de imagen ───────────────────────────────────────

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      setState(() => _error = 'La imagen no debe superar 5 MB');
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _imageName  = picked.name;
      _imageFile  = File(picked.path);
      _error      = null;
    });
  }

  // ── Subida del voucher ────────────────────────────────────────

  Future<void> _subirVoucher() async {
    setState(() { _uploading = true; _error = null; });
    try {
      final formData = FormData.fromMap({
        'imagen': MultipartFile.fromBytes(
          _imageBytes!,
          filename: _imageName ?? 'voucher.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });
      await ApiClient().dio.post(
        '/pagos/${widget.pagoId}/voucher',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      setState(() => _uploading = false);
      if (mounted) {
        widget.onVoucherSubido();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[PagoModal] Error subiendo voucher: $e');
      if (!mounted) return;
      setState(() {
        _error     = 'Error al subir. Intenta de nuevo.';
        _uploading = false;
      });
    }
  }

  void _confirmarPagoLocal() {
    widget.onVoucherSubido();
    Navigator.pop(context);
  }

  // ── Helpers ───────────────────────────────────────────────────

  bool get _esPagoLocal =>
      widget.metodoPago == 'efectivo' || widget.metodoPago == 'tarjeta';

  bool get _tieneImagen => _imageBytes != null;

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final datos = _datosPago[widget.metodoPago] ?? _datosPago['yape']!;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PagoHandleBar(),
            const SizedBox(height: 16),
            _PagoHeader(
              titulo: _esPagoLocal
                  ? 'CONFIRMACIÓN DE RESERVA'
                  : 'REALIZAR PAGO',
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
            _MontoCard(
              icono:      datos['icono']!,
              numero:     datos['numero']!,
              titular:    datos['titular']!,
              monto:      widget.monto,
              esPagoLocal: _esPagoLocal,
              qrBase64:   _esPagoLocal ? null : _qrBase64,
            ),
            const SizedBox(height: 16),
            if (_esPagoLocal) ...[
              _MensajePagoLocal(metodoPago: widget.metodoPago),
              const SizedBox(height: 16),
            ] else ...[
              _SeccionVoucher(
                tieneImagen:   _tieneImagen,
                imageBytes:    _imageBytes,
                onSeleccionar: _seleccionarImagen,
                onQuitarImagen: () => setState(() {
                  _imageBytes = null;
                  _imageFile  = null;
                  _imageName  = null;
                }),
              ),
              if (_imageName != null) ...[
                const SizedBox(height: 6),
                _InfoArchivo(nombre: _imageName!, bytes: _imageBytes!),
              ],
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              _PagoErrorBanner(mensaje: _error!),
              const SizedBox(height: 10),
            ],
            _BotonPago(
              esPagoLocal: _esPagoLocal,
              tieneImagen: _tieneImagen,
              uploading:   _uploading,
              onPagoLocal: _confirmarPagoLocal,
              onSubirVoucher: _subirVoucher,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _PagoHandleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borde,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _PagoHeader extends StatelessWidget {
  const _PagoHeader({required this.titulo, required this.onClose});

  final String titulo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.verde,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: AppColors.texto2, size: 20),
          ),
        ],
      );
}

/// Card con los datos de destino del pago y el monto destacado.
class _MontoCard extends StatelessWidget {
  const _MontoCard({
    required this.icono,
    required this.numero,
    required this.titular,
    required this.monto,
    required this.esPagoLocal,
    this.qrBase64,
  });

  final String  icono;
  final String  numero;
  final String  titular;
  final double  monto;
  final bool    esPagoLocal;
  final String? qrBase64;   // base64 data URL o null

  /// Decodifica la imagen QR (base64 o URL directa)
  Widget? _buildQr() {
    if (qrBase64 == null || qrBase64!.isEmpty) return null;
    if (qrBase64!.startsWith('data:')) {
      final commaIdx = qrBase64!.indexOf(',');
      if (commaIdx != -1) {
        try {
          final bytes = base64Decode(qrBase64!.substring(commaIdx + 1));
          return Image.memory(bytes, width: 160, height: 160, fit: BoxFit.contain);
        } catch (_) {}
      }
    }
    return Image.network(qrBase64!, width: 160, height: 160, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) {
    final qrWidget = _buildQr();
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.negro3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          children: [
            // QR si está disponible; sino icono del método
            if (qrWidget != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: qrWidget,
              ),
              const SizedBox(height: 8),
            ] else ...[
              Text(icono, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
            ],
            Text(
              esPagoLocal ? 'Paga al llegar:' : 'Envía el pago a:',
              style: const TextStyle(fontSize: 12, color: AppColors.texto2),
            ),
            const SizedBox(height: 4),
            // Soporte de texto multilínea (ej: "BCP: xxx\nBBVA: yyy")
            Text(
              numero,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            if (titular.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                titular,
                style: const TextStyle(fontSize: 12, color: AppColors.texto2),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'S/ ${monto.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.verde),
            ),
          ],
        ),
      );
  }
}

/// Mensaje informativo para pagos en efectivo o tarjeta.
class _MensajePagoLocal extends StatelessWidget {
  const _MensajePagoLocal({required this.metodoPago});

  final String metodoPago;

  @override
  Widget build(BuildContext context) {
    final esEfectivo = metodoPago == 'efectivo';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verde.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.verde.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.verde, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              esEfectivo
                  ? 'Tu reserva fue registrada. Paga en efectivo al llegar al local. El administrador verificará el pago en ese momento.'
                  : 'Tu reserva fue registrada. Presenta tu tarjeta al llegar al local. El administrador verificará el pago en ese momento.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.texto, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Área de carga de imagen con preview o placeholder.
class _SeccionVoucher extends StatelessWidget {
  const _SeccionVoucher({
    required this.tieneImagen,
    required this.imageBytes,
    required this.onSeleccionar,
    required this.onQuitarImagen,
  });

  final bool         tieneImagen;
  final Uint8List?   imageBytes;
  final VoidCallback onSeleccionar;
  final VoidCallback onQuitarImagen;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUBIR VOUCHER / CAPTURA',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.texto2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: tieneImagen ? null : onSeleccionar,
            child: Container(
              width: double.infinity,
              height: tieneImagen ? 160 : 100,
              decoration: BoxDecoration(
                color: AppColors.negro3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: tieneImagen ? AppColors.verde : AppColors.borde),
              ),
              child: tieneImagen
                  ? _PreviewImagen(
                      bytes: imageBytes!,
                      onQuitar: onQuitarImagen,
                    )
                  : const _PlaceholderVoucher(),
            ),
          ),
        ],
      );
}

/// Preview de la imagen seleccionada con botón de quitar.
class _PreviewImagen extends StatelessWidget {
  const _PreviewImagen({required this.bytes, required this.onQuitar});

  final Uint8List    bytes;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onQuitar,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
}

/// Placeholder cuando no hay imagen seleccionada.
class _PlaceholderVoucher extends StatelessWidget {
  const _PlaceholderVoucher();

  @override
  Widget build(BuildContext context) => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📷', style: TextStyle(fontSize: 28)),
          SizedBox(height: 6),
          Text(
            'Toca para seleccionar imagen',
            style: TextStyle(fontSize: 12, color: AppColors.texto2),
          ),
          SizedBox(height: 2),
          Text(
            'Máximo 5 MB · JPG / PNG',
            style: TextStyle(fontSize: 10, color: AppColors.texto2),
          ),
        ],
      );
}

/// Muestra el nombre y tamaño del archivo seleccionado.
class _InfoArchivo extends StatelessWidget {
  const _InfoArchivo({required this.nombre, required this.bytes});

  final String    nombre;
  final Uint8List bytes;

  String get _tamano {
    final kb = bytes.lengthInBytes / 1024;
    return kb < 1024
        ? '${kb.toStringAsFixed(0)} KB'
        : '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.attach_file, color: AppColors.texto2, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(fontSize: 11, color: AppColors.texto2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _tamano,
            style: const TextStyle(fontSize: 11, color: AppColors.texto2),
          ),
        ],
      );
}

/// Banner de error rojo.
class _PagoErrorBanner extends StatelessWidget {
  const _PagoErrorBanner({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.rojo.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.rojo.withOpacity(0.4)),
        ),
        child: Text(
          mensaje,
          style: const TextStyle(color: AppColors.rojo, fontSize: 13),
        ),
      );
}

/// Botón de acción principal: "Entendido" (pago local) o "Subir Voucher".
class _BotonPago extends StatelessWidget {
  const _BotonPago({
    required this.esPagoLocal,
    required this.tieneImagen,
    required this.uploading,
    required this.onPagoLocal,
    required this.onSubirVoucher,
  });

  final bool         esPagoLocal;
  final bool         tieneImagen;
  final bool         uploading;
  final VoidCallback onPagoLocal;
  final VoidCallback onSubirVoucher;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: uploading
              ? null
              : esPagoLocal
                  ? onPagoLocal
                  : tieneImagen
                      ? onSubirVoucher
                      : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verde,
            foregroundColor: AppColors.negro,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: uploading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.negro),
                )
              : Text(
                  esPagoLocal
                      ? '✅ Entendido — Mi reserva está lista'
                      : '✅ Enviar Voucher y Confirmar',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
        ),
      );
}
