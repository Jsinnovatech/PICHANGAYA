/// Equivale a CLIENTES[] del HTML
class UserModel {
  final String id;
  final String nombre;
  final String celular;
  final String? dni;
  final String rol; // 'cliente' | 'admin'
  final bool activo;

  const UserModel({
    required this.id,
    required this.nombre,
    required this.celular,
    this.dni,
    required this.rol,
    required this.activo,
  });

  bool get isAdmin => rol == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'],
        nombre: j['nombre'],
        celular: j['celular'],
        dni: j['dni'],
        rol: j['rol'],
        activo: j['activo'] ?? true,
      );
}
