/// Equivale a RESERVAS[] del HTML
class ReservaModel {
  final String id;
  final String codigo;
  final String clienteId;
  final String clienteNombre;
  final String canchaId;
  final String? canchaNombre;
  final String fecha;       // 'YYYY-MM-DD'
  final String horaInicio;  // 'HH:MM'
  final String horaFin;
  final double precioTotal;
  final String estado;      // 'pending'|'confirmed'|'active'|'done'|'canceled'
  final String? tipoDoc;    // 'boleta'|'factura'
  final String? metodoPago; // 'yape'|'plin'|'transferencia'|'efectivo'
  final String? serieFact;

  const ReservaModel({
    required this.id,
    required this.codigo,
    required this.clienteId,
    required this.clienteNombre,
    required this.canchaId,
    this.canchaNombre,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.precioTotal,
    required this.estado,
    this.tipoDoc,
    this.metodoPago,
    this.serieFact,
  });

  factory ReservaModel.fromJson(Map<String, dynamic> j) => ReservaModel(
        id: j['id'],
        codigo: j['codigo'] ?? j['id'],
        clienteId: j['cliente_id'],
        clienteNombre: j['cliente_nombre'] ?? '',
        canchaId: j['cancha_id'],
        canchaNombre: j['cancha_nombre'],
        fecha: j['fecha'],
        horaInicio: j['hora_inicio'],
        horaFin: j['hora_fin'],
        precioTotal: (j['precio_total'] as num).toDouble(),
        estado: j['estado'],
        tipoDoc: j['tipo_doc'],
        metodoPago: j['metodo_pago'],
        serieFact: j['serie_fact'],
      );
}
