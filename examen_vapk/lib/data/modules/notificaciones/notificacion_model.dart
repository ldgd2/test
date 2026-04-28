class NotificacionModel {
  final String  id;
  final String  titulo;
  final String  cuerpo;
  final bool    leida;
  final String? createdAt;
  final Map<String, dynamic>? datosExtra;

  NotificacionModel({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.leida,
    this.createdAt,
    this.datosExtra,
  });

  factory NotificacionModel.fromJson(Map<String, dynamic> json) {
    return NotificacionModel(
      id:         json['id']     ?? '',
      titulo:     json['titulo'] ?? '',
      cuerpo:     json['cuerpo'] ?? '',
      leida:      json['leida']  ?? false,
      createdAt:  json['created_at']?.toString(),
      datosExtra: json['datos_extra'] is String
          ? null
          : json['datos_extra'] as Map<String, dynamic>?,
    );
  }
}