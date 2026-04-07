class ReservaModel {
  final String id;
  final String codigo;
  final String? canchaNombre;
  final String? localNombre;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final double precioTotal;
  final String estado;
  final String? tipoDoc;
  final String? metodoPago;
  final String? serieFact;

  const ReservaModel({
    required this.id,
    required this.codigo,
    this.canchaNombre,
    this.localNombre,
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
        canchaNombre: j['cancha_nombre'],
        localNombre: j['local_nombre'],
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
