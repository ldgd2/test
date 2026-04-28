class PagoModel {
  final String  id;
  final String  asignacionId;
  final double  montoTotal;
  final double  comisionPlataforma;
  final double  montoTaller;
  final String  metodo;
  final String  estado;
  final String? descripcion;
  final String? qrImagenUrl;
  final String? comprobanteUrl;
  final String? referenciaExterna;
  final String? pagadoAt;
  final String  createdAt;
  final String? tallerNombre;
  final String? tecnicoNombre;
  final String? categoria;
  final String? descripcionIncidente;

  PagoModel({
    required this.id,
    required this.asignacionId,
    required this.montoTotal,
    required this.comisionPlataforma,
    required this.montoTaller,
    required this.metodo,
    required this.estado,
    this.descripcion,
    this.qrImagenUrl,
    this.comprobanteUrl,
    this.referenciaExterna,
    this.pagadoAt,
    required this.createdAt,
    this.tallerNombre,
    this.tecnicoNombre,
    this.categoria,
    this.descripcionIncidente,
  });

  factory PagoModel.fromJson(Map<String, dynamic> json) {
    return PagoModel(
      id:                   json['id']                    ?? '',
      asignacionId:         json['asignacion_id']         ?? '',
      montoTotal:           double.tryParse(json['monto_total'].toString()) ?? 0,
      comisionPlataforma:   double.tryParse(json['comision_plataforma'].toString()) ?? 0,
      montoTaller:          double.tryParse(json['monto_taller'].toString()) ?? 0,
      metodo:               json['metodo']                ?? '',
      estado:               json['estado']                ?? '',
      descripcion:          json['descripcion'],
      qrImagenUrl:          json['qr_imagen_url'],
      comprobanteUrl:       json['comprobante_url'],
      referenciaExterna:    json['referencia_externa'],
      pagadoAt:             json['pagado_at']?.toString(),
      createdAt:            json['created_at']?.toString() ?? '',
      tallerNombre:         json['taller_nombre'],
      tecnicoNombre:        json['tecnico_nombre'],
      categoria:            json['categoria'],
      descripcionIncidente: json['descripcion_incidente'],
    );
  }

  bool get estaPagado => estado == 'procesado';
}