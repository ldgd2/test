import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../../core/environment.dart';
import 'vehicle_model.dart';

class VehicleService {
  final String baseUrl = Environment.baseUrl;

  // ══════════════════════════════════════════════════════
  // REGISTRAR — POST /api/vehiculos/
  // ══════════════════════════════════════════════════════
  Future<VehicleModel?> registrarVehiculo(
    VehicleModel vehicle,
    String token, {
    File?      fotoFile,
    Uint8List? fotoBytes,
    String?    fotoNombre,
  }) async {
    try {
      // Paso 1 — JSON
      final response = await http.post(
        Uri.parse('$baseUrl/vehiculos/'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(vehicle.toJson()),
      );

      print("✅ Status registro: ${response.statusCode}");
      print("✅ Body registro:   ${response.body}");

      if (response.statusCode != 200 && response.statusCode != 201) {
        print("❌ Error registro: ${response.body}");
        return null;
      }

      final creado = VehicleModel.fromJson(jsonDecode(response.body));

      // Paso 2 — Foto opcional
      if (creado.id != null && (fotoBytes != null || fotoFile != null)) {
        await _subirFoto(
          vehiculoId: creado.id!,
          token:      token,
          fotoFile:   fotoFile,
          fotoBytes:  fotoBytes,
          fotoNombre: fotoNombre,
        );
      }

      return creado;
    } catch (e) {
      print("❌ Error conexión registro: $e");
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  // ACTUALIZAR — PUT /api/vehiculos/{id}
  // ══════════════════════════════════════════════════════
  Future<bool> actualizarVehiculo(VehicleModel vehicle, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/vehiculos/${vehicle.id}'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(vehicle.toJson()),
      );

      print("✅ Status actualizar: ${response.statusCode}");
      print("✅ Body actualizar:   ${response.body}");

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("❌ Error actualizando: $e");
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  // ELIMINAR — DELETE /api/vehiculos/{id}
  // ══════════════════════════════════════════════════════
  Future<bool> eliminarVehiculo(String vehiculoId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/vehiculos/$vehiculoId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("🗑️ Status eliminar: ${response.statusCode}");
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("❌ Error eliminando: $e");
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  // LISTAR MIS VEHÍCULOS — GET /api/vehiculos/mis-vehiculos
  // ══════════════════════════════════════════════════════
  Future<List<VehicleModel>> listarMisVehiculos(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehiculos/mis-vehiculos'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("📋 Status listar: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => VehicleModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("❌ Error listando: $e");
      return [];
    }
  }

  // ══════════════════════════════════════════════════════
  // SUBIR FOTO — POST /api/vehiculos/{id}/foto
  // ══════════════════════════════════════════════════════
  Future<void> _subirFoto({
    required String vehiculoId,
    required String token,
    File?      fotoFile,
    Uint8List? fotoBytes,
    String?    fotoNombre,
  }) async {
    try {
      final uri     = Uri.parse('$baseUrl/vehiculos/$vehiculoId/foto');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      if (kIsWeb && fotoBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'foto', fotoBytes, filename: fotoNombre ?? 'foto.jpg',
        ));
      } else if (!kIsWeb && fotoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto', fotoFile.path),
        );
      }

      final streamed = await request.send();
      final resp     = await http.Response.fromStream(streamed);
      print("📷 Status foto: ${resp.statusCode}");
    } catch (e) {
      print("❌ Error subiendo foto: $e");
    }
  }
}