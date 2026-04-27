/// Equivale a CANCHAS[] del HTML
class CanchaModel {
  final String id;
  final String localId;
  final String nombre;
  final int capacidad;
  final double precioHora;
  final double? precioDia;    // franja 07:00–18:00
  final double? precioNoche;  // franja 18:00–00:00
  final String? superficie; // 'Gras Sintético' | 'Piso Madera' | 'Cemento'
  final String? fotoUrl;
  final bool activa;

  const CanchaModel({
    required this.id,
    required this.localId,
    required this.nombre,
    required this.capacidad,
    required this.precioHora,
    this.precioDia,
    this.precioNoche,
    this.superficie,
    this.fotoUrl,
    required this.activa,
  });

  factory CanchaModel.fromJson(Map<String, dynamic> j) => CanchaModel(
        id: j['id'],
        localId: j['local_id'],
        nombre: j['nombre'],
        capacidad: j['capacidad'],
        precioHora: (j['precio_hora'] as num).toDouble(),
        precioDia: j['precio_dia'] != null ? (j['precio_dia'] as num).toDouble() : null,
        precioNoche: j['precio_noche'] != null ? (j['precio_noche'] as num).toDouble() : null,
        superficie: j['superficie'],
        fotoUrl: j['foto_url'],
        activa: j['activa'] ?? true,
      );
}
