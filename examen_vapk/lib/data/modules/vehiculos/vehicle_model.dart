class VehicleModel {
  final String? id;
  final String placa;
  final String marca;
  final String modelo;
  final int anio;
  final String? color;
  final String combustible;
  final String? fotoUrl;

  VehicleModel({
    this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.anio,
    this.color,
    this.combustible = 'gasolina',
    this.fotoUrl,
  });

  // Convierte el objeto a JSON para enviarlo a FastAPI
  Map<String, dynamic> toJson() {
    return {
      "placa": placa,
      "marca": marca,
      "modelo": modelo,
      "anio": anio,
      "color": color,
      "combustible": combustible,
    };
  }

  // Crea un objeto desde el JSON que responde el servidor
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      placa: json['placa'],
      marca: json['marca'],
      modelo: json['modelo'],
      anio: json['anio'],
      color: json['color'],
      combustible: json['combustible'],
      fotoUrl: json['foto_url'],
    );
  }
}