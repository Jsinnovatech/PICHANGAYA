/// Equivale a PAGOS[] del HTML
class PagoModel {
  final String id;
  final String reservaId;
  final String clienteId;
  final double monto;
  final String metodo;  // 'yape'|'plin'|'transferencia'|'efectivo'
  final String estado;  // 'pendiente'|'verificado'|'rechazado'
  final String? voucherUrl;
  final String? comprobanteExt;
  final String fecha;

  const PagoModel({
    required this.id,
    required this.reservaId,
    required this.clienteId,
    required this.monto,
    required this.metodo,
    required this.estado,
    this.voucherUrl,
    this.comprobanteExt,
    required this.fecha,
  });

  factory PagoModel.fromJson(Map<String, dynamic> j) => PagoModel(
        id: j['id'],
        reservaId: j['reserva_id'],
        clienteId: j['cliente_id'],
        monto: (j['monto'] as num).toDouble(),
        metodo: j['metodo'],
        estado: j['estado'],
        voucherUrl: j['voucher_url'],
        comprobanteExt: j['comprobante_ext'],
        fecha: j['fecha'],
      );
}
