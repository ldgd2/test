class IncidenteModel {
  final String? id;
  final String  vehiculoId;
  final String  categoria;
  final String  descripcionManual;
  final String  direccionTexto;
  final String  ubicacion;
  final String  prioridad;
  final String? estado;
  final String? resumenIa;
  final double? confianzaIa;
  final bool?   requiereRevision;
  final String? fotoEvidencia;
  final String? createdAt;

  IncidenteModel({
    this.id,
    required this.vehiculoId,
    required this.categoria,
    required this.descripcionManual,
    required this.direccionTexto,
    required this.ubicacion,
    this.prioridad     = 'media',
    this.estado,
    this.resumenIa,
    this.confianzaIa,
    this.requiereRevision,
    this.fotoEvidencia,
    this.createdAt,
  });

  factory IncidenteModel.fromJson(Map<String, dynamic> json) {
    return IncidenteModel(
      id:                json['id'],
      vehiculoId:        json['vehiculo_id'],
      categoria:         json['categoria'],
      descripcionManual: json['descripcion_manual'],
      direccionTexto:    json['direccion_texto'] ?? '',
      ubicacion:         json['ubicacion']       ?? '0,0',
      prioridad:         json['prioridad']       ?? 'media',
      estado:            json['estado'],
      resumenIa:         json['resumen_ia'],
      confianzaIa:       json['confianza_ia'] != null
                           ? double.tryParse(json['confianza_ia'].toString())
                           : null,
      requiereRevision:  json['requiere_revision'],
      fotoEvidencia:     json['foto_evidencia'],
      createdAt:         json['created_at']?.toString(),
    );
  }
}