class PagoModel {
  final String id;
  final String reservaId;
  final String? reservaCodigo;
  final double monto;
  final String metodo;
  final String estado;
  final String? voucherUrl;
  final String fecha;

  const PagoModel({
    required this.id,
    required this.reservaId,
    this.reservaCodigo,
    required this.monto,
    required this.metodo,
    required this.estado,
    this.voucherUrl,
    required this.fecha,
  });

  factory PagoModel.fromJson(Map<String, dynamic> j) => PagoModel(
        id: j['id'],
        reservaId: j['reserva_id'],
        reservaCodigo: j['reserva_codigo'],
        monto: (j['monto'] as num).toDouble(),
        metodo: j['metodo'],
        estado: j['estado'],
        voucherUrl: j['voucher_url'],
        fecha: j['fecha'] ?? '',
      );
}
