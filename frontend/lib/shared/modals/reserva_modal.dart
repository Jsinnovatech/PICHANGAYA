import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/shared/modals/pago_modal.dart';

/// Modal Paso 1 — confirmar la reserva y elegir método de pago.
///
/// Parámetros:
/// - [canchaId]     ID de la cancha en el backend
/// - [canchaName]   Nombre legible de la cancha
/// - [localName]    Nombre del local deportivo
/// - [fecha]        Fecha de la reserva (objeto DateTime)
/// - [horaInicio]   Hora de inicio en formato "HH:MM"
/// - [horaFin]      Hora de fin en formato "HH:MM"
/// - [precioTotal]  Precio calculado según duración
/// - [nombreInicial / telefonoInicial / dniInicial]  Datos pre-rellenos del cliente
/// - [onReservado]  Callback al completar el flujo completo (reserva + pago)
class ReservaModal extends StatefulWidget {
  final String canchaId;
  final String canchaName;
  final String localName;
  final String? localId;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final double precioTotal;
  final String nombreInicial;
  final String telefonoInicial;
  final String dniInicial;
  final VoidCallback onReservado;

  const ReservaModal({
    super.key,
    required this.canchaId,
    required this.canchaName,
    required this.localName,
    this.localId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.precioTotal,
    this.nombreInicial = '',
    this.telefonoInicial = '',
    this.dniInicial = '',
    required this.onReservado,
  });

  /// Abre el modal como bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String canchaId,
    required String canchaName,
    required String localName,
    String? localId,
    required DateTime fecha,
    required String horaInicio,
    required String horaFin,
    required double precioTotal,
    String nombreInicial = '',
    String telefonoInicial = '',
    String dniInicial = '',
    required VoidCallback onReservado,
  }) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ReservaModal(
          canchaId: canchaId,
          canchaName: canchaName,
          localName: localName,
          localId: localId,
          fecha: fecha,
          horaInicio: horaInicio,
          horaFin: horaFin,
          precioTotal: precioTotal,
          nombreInicial: nombreInicial,
          telefonoInicial: telefonoInicial,
          dniInicial: dniInicial,
          onReservado: onReservado,
        ),
      );

  @override
  State<ReservaModal> createState() => _ReservaModalState();
}

class _ReservaModalState extends State<ReservaModal> {
  // ── Estado ────────────────────────────────────────────────────
  String _metodoPago = 'yape';
  String _tipoDoc    = 'boleta';
  bool   _loading    = false;
  String? _error;

  // ── Controllers ───────────────────────────────────────────────
  late final TextEditingController _dniCtrl;
  late final TextEditingController _rucCtrl;
  late final TextEditingController _razonSocialCtrl;
  late final TextEditingController _notasCtrl;

  // ── Formato de fecha (intl) ───────────────────────────────────
  static final _fmtFecha    = DateFormat("dd-MM-yyyy");
  static final _fmtFechaApi = DateFormat("yyyy-MM-dd");

  @override
  void initState() {
    super.initState();
    _dniCtrl         = TextEditingController(text: widget.dniInicial);
    _rucCtrl         = TextEditingController();
    _razonSocialCtrl = TextEditingController();
    _notasCtrl       = TextEditingController();
  }

  @override
  void dispose() {
    _dniCtrl.dispose();
    _rucCtrl.dispose();
    _razonSocialCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  // ── Lógica de confirmación ────────────────────────────────────

  Future<void> _confirmarReserva() async {
    if (_tipoDoc == 'factura') {
      final ruc = _rucCtrl.text.trim();
      final rs  = _razonSocialCtrl.text.trim();
      if (ruc.length != 11 || int.tryParse(ruc) == null) {
        setState(() => _error = 'El RUC debe tener exactamente 11 dígitos');
        return;
      }
      if (rs.isEmpty) {
        setState(() => _error = 'La razón social es obligatoria para factura');
        return;
      }
    }

    setState(() { _loading = true; _error = null; });

    try {
      final body = <String, dynamic>{
        'cancha_id':   widget.canchaId,
        'fecha':       _fmtFechaApi.format(widget.fecha),
        'hora_inicio': widget.horaInicio,
        'hora_fin':    widget.horaFin,
        'metodo_pago': _metodoPago,
        'tipo_doc':    _tipoDoc,
        if (_tipoDoc == 'factura') 'ruc_factura':  _rucCtrl.text.trim(),
        if (_tipoDoc == 'factura') 'razon_social': _razonSocialCtrl.text.trim(),
        if (_notasCtrl.text.trim().isNotEmpty) 'notas': _notasCtrl.text.trim(),
      };

      final res = await ApiClient().dio.post(ApiConstants.reservas, data: body);
      final pagoId = res.data['pago_id']?.toString() ?? '';

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pop(context);

      // Abrir modal de pago directamente
      await PagoModal.show(
        context,
        pagoId: pagoId,
        monto: widget.precioTotal,
        metodoPago: _metodoPago,
        canchaName: widget.canchaName,
        localId: widget.localId,
        onVoucherSubido: widget.onReservado,
      );
    } on DioException catch (e) {
      debugPrint('[ReservaModal] DioException type=${e.type} status=${e.response?.statusCode} msg=${e.message}');
      final data   = e.response?.data;
      final status = e.response?.statusCode;
      String msg;
      if (status == 409) {
        msg = 'Este horario ya fue reservado. Elige otro.';
      } else if (status == 400 || status == 422) {
        final detail = data is Map ? data['detail'] : null;
        msg = detail != null ? detail.toString() : 'Datos inválidos. Verifica los campos.';
      } else if (status == 401) {
        msg = 'Sesión expirada. Vuelve a iniciar sesión.';
      } else if (data is Map && data['detail'] != null) {
        msg = data['detail'].toString();
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        msg = 'El servidor tardó en responder. Intenta de nuevo.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        msg = 'El servidor demoró en procesar la reserva. Verifica en "Mis reservas" si fue creada.';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'Sin internet. Verifica tu conexión y vuelve a intentarlo.';
      } else {
        msg = 'Error (${e.type.name}): ${e.message ?? "Intenta de nuevo"}';
      }
      if (!mounted) return;
      setState(() { _error = msg; _loading = false; });
    } catch (e) {
      debugPrint('[ReservaModal] Error inesperado: $e');
      if (!mounted) return;
      setState(() { _error = 'Error inesperado: $e'; _loading = false; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HandleBar(),
            const SizedBox(height: 16),
            _ModalHeader(onClose: () => Navigator.pop(context)),
            const SizedBox(height: 16),
            _ResumenCard(
              canchaName:  widget.canchaName,
              localName:   widget.localName,
              fechaLabel:  _fmtFecha.format(widget.fecha),
              horaInicio:  widget.horaInicio,
              horaFin:     widget.horaFin,
              precioTotal: widget.precioTotal,
            ),
            const SizedBox(height: 14),
            _CampoLectura(label: 'NOMBRE',
                valor: widget.nombreInicial.isNotEmpty ? widget.nombreInicial : '—'),
            const SizedBox(height: 10),
            _CampoLectura(label: 'TELÉFONO',
                valor: widget.telefonoInicial.isNotEmpty ? widget.telefonoInicial : '—'),
            const SizedBox(height: 10),
            _CampoDni(controller: _dniCtrl),
            const SizedBox(height: 14),
            _SelectorMetodoPago(
              seleccionado: _metodoPago,
              onSeleccionar: (m) => setState(() => _metodoPago = m),
            ),
            const SizedBox(height: 14),
            _SelectorTipoDoc(
              seleccionado: _tipoDoc,
              onSeleccionar: (d) => setState(() { _tipoDoc = d; _error = null; }),
            ),
            if (_tipoDoc == 'factura') ...[
              const SizedBox(height: 14),
              _CamposFactura(rucCtrl: _rucCtrl, razonCtrl: _razonSocialCtrl),
            ],
            const SizedBox(height: 12),
            _CampoNotas(controller: _notasCtrl),
            const SizedBox(height: 16),
            if (_error != null) ...[
              _ErrorBanner(mensaje: _error!),
              const SizedBox(height: 10),
            ],
            _BotonConfirmar(
              loading: _loading,
              onPressed: _confirmarReserva,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS — extraídos para mantener build() corto y reutilizables
// ══════════════════════════════════════════════════════════════════════════════

/// Barra de arrastre en la parte superior del bottom sheet.
class _HandleBar extends StatelessWidget {
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

/// Título del modal + botón cerrar.
class _ModalHeader extends StatelessWidget {
  const _ModalHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Text(
            'RESERVAR CANCHA',
            style: TextStyle(
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

/// Card de resumen con datos de la reserva (readonly).
class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.canchaName,
    required this.localName,
    required this.fechaLabel,
    required this.horaInicio,
    required this.horaFin,
    required this.precioTotal,
  });

  final String canchaName;
  final String localName;
  final String fechaLabel;
  final String horaInicio;
  final String horaFin;
  final double precioTotal;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.negro3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.sports_soccer, color: AppColors.verde, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  canchaName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, color: AppColors.texto2, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  localName,
                  style: const TextStyle(fontSize: 11, color: AppColors.texto2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today, color: AppColors.texto2, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fechaLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.texto2),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time, color: AppColors.texto2, size: 12),
              const SizedBox(width: 6),
              Text(
                '$horaInicio → $horaFin',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2),
              ),
            ]),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'S/ ${precioTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.verde,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Campo de texto de solo lectura (nombre, teléfono).
class _CampoLectura extends StatelessWidget {
  const _CampoLectura({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.texto2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.negro3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borde),
            ),
            child: Text(
              valor,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70),
            ),
          ),
        ],
      );
}

/// Campo editable para DNI / RUC.
class _CampoDni extends StatelessWidget {
  const _CampoDni({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DNI / RUC',
            style: TextStyle(
                fontSize: 10,
                color: AppColors.texto2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 11,
            decoration: const InputDecoration(
              hintText: 'Ingresa tu DNI o RUC',
              counterText: '',
            ),
          ),
        ],
      );
}

/// Selector de método de pago (Yape / Plin / Transfer. / Efectivo).
class _SelectorMetodoPago extends StatelessWidget {
  const _SelectorMetodoPago({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final String seleccionado;
  final ValueChanged<String> onSeleccionar;

  static const _opciones = [
    ('yape',          'Yape',      '📱', 'Al instante'),
    ('plin',          'Plin',      '💙', 'Al instante'),
    ('transferencia', 'Transfer.', '🏦', 'BCP/BBVA'),
    ('efectivo',      'Efectivo',  '💵', 'En local'),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MÉTODO DE PAGO',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.texto2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: _opciones.map((m) {
              final activo = seleccionado == m.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSeleccionar(m.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: activo
                          ? AppColors.verde.withOpacity(0.15)
                          : AppColors.negro3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: activo ? AppColors.verde : AppColors.borde,
                          width: activo ? 1.5 : 1),
                    ),
                    child: Column(children: [
                      Text(m.$3, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        m.$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: activo ? AppColors.verde : Colors.white,
                        ),
                      ),
                      Text(
                        m.$4,
                        style: const TextStyle(
                            fontSize: 8, color: AppColors.texto2),
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
}

/// Selector de tipo de documento (Boleta / Factura).
class _SelectorTipoDoc extends StatelessWidget {
  const _SelectorTipoDoc({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final String seleccionado;
  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Text('Doc:', style: TextStyle(color: AppColors.texto2, fontSize: 12)),
          const SizedBox(width: 8),
          ...[('boleta', 'Boleta'), ('factura', 'Factura')].map((d) {
            final activo = seleccionado == d.$1;
            return GestureDetector(
              onTap: () => onSeleccionar(d.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: activo
                      ? AppColors.verde.withOpacity(0.15)
                      : AppColors.negro3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: activo ? AppColors.verde : AppColors.borde),
                ),
                child: Text(
                  d.$2,
                  style: TextStyle(
                    fontSize: 12,
                    color: activo ? AppColors.verde : AppColors.texto2,
                    fontWeight:
                        activo ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      );
}

/// Campos de RUC y Razón Social (solo visibles cuando tipoDoc == 'factura').
class _CamposFactura extends StatelessWidget {
  const _CamposFactura({
    required this.rucCtrl,
    required this.razonCtrl,
  });

  final TextEditingController rucCtrl;
  final TextEditingController razonCtrl;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amarillo.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.amarillo.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.info_outline, color: AppColors.amarillo, size: 14),
              SizedBox(width: 6),
              Text(
                'Datos para la factura electrónica',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.amarillo,
                    fontWeight: FontWeight.w700),
              ),
            ]),
            const SizedBox(height: 12),
            const Text(
              'RUC DE LA EMPRESA *',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.texto2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: rucCtrl,
              keyboardType: TextInputType.number,
              maxLength: 11,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: '20XXXXXXXXX',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'RAZÓN SOCIAL *',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.texto2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: razonCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(hintText: 'EMPRESA SAC'),
            ),
          ],
        ),
      );
}

/// Campo opcional para notas / instrucciones adicionales.
class _CampoNotas extends StatelessWidget {
  const _CampoNotas({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOTAS (opcional)',
            style: TextStyle(
                fontSize: 10,
                color: AppColors.texto2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Instrucciones adicionales o comentarios...',
            ),
          ),
        ],
      );
}

/// Banner rojo que muestra mensajes de error.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.mensaje});

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

/// Botón principal "Confirmar Reserva" con estado de carga.
class _BotonConfirmar extends StatelessWidget {
  const _BotonConfirmar({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verde,
            foregroundColor: AppColors.negro,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.negro),
                )
              : const Text(
                  '💰 Confirmar Reserva',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
        ),
      );
}
