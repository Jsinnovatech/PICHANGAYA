/// Equivale a LOCALES[] del HTML
class LocalModel {
  final String id;
  final String nombre;
  final String direccion;
  final double lat;
  final double lng;
  final String? telefono;
  final String? fotoUrl;
  final double? distanciaKm; // calculado en backend con Haversine

  const LocalModel({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.lat,
    required this.lng,
    this.telefono,
    this.fotoUrl,
    this.distanciaKm,
  });

  factory LocalModel.fromJson(Map<String, dynamic> j) => LocalModel(
        id: j['id'],
        nombre: j['nombre'],
        direccion: j['direccion'],
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        telefono: j['telefono'],
        fotoUrl: j['foto_url'],
        distanciaKm: j['distancia_km'] != null ? (j['distancia_km'] as num).toDouble() : null,
      );
}
