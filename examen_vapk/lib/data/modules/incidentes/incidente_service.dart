import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../../core/environment.dart';
import 'incidente_model.dart';

class IncidenteService {
  final String baseUrl = Environment.baseUrl;

  // ══════════════════════════════════════════════════════
  // REPORTAR INCIDENTE — POST /api/incidentes/
  // Envía multipart/form-data igual que el Angular
  // ══════════════════════════════════════════════════════
  Future<IncidenteModel?> reportarIncidente({
    required String token,
    required String vehiculoId,
    required String categoria,
    required String descripcionManual,
    required String direccionTexto,
    required String ubicacion,
    String     prioridad  = 'media',
    File?      fotoFile,
    Uint8List? fotoBytes,
    String?    fotoNombre,
  }) async {
    try {
      final uri     = Uri.parse('$baseUrl/incidentes/');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      // Campos de texto
      request.fields['vehiculo_id']        = vehiculoId;
      request.fields['categoria']           = categoria;
      request.fields['descripcion_manual']  = descripcionManual;
      request.fields['direccion_texto']     = direccionTexto;
      request.fields['ubicacion']           = ubicacion;
      request.fields['prioridad']           = prioridad;

      // Foto opcional
      if (kIsWeb && fotoBytes != null && fotoNombre != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'foto', fotoBytes, filename: fotoNombre,
        ));
      } else if (!kIsWeb && fotoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto', fotoFile.path),
        );
      }

      final streamed  = await request.send();
      final response  = await http.Response.fromStream(streamed);

      print("✅ Status incidente: ${response.statusCode}");
      print("✅ Body incidente:   ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return IncidenteModel.fromJson(jsonDecode(response.body));
      } else {
        print("❌ Error incidente: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Error conexión incidente: $e");
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  // MIS INCIDENTES — GET /api/incidentes/mis-incidentes
  // ══════════════════════════════════════════════════════
  Future<List<IncidenteModel>> misIncidentes(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/incidentes/mis-incidentes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => IncidenteModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("❌ Error mis incidentes: $e");
      return [];
    }
  }
}