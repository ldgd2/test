import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../../core/environment.dart';
import 'pago_model.dart';

class PagoService {
  final String baseUrl = Environment.baseUrl;

  // ── Obtener pago por asignación ───────────────────────────
  Future<PagoModel?> getPagoPorAsignacion(
      String asignacionId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pagos/asignacion/$asignacionId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return PagoModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo pago: $e');
      return null;
    }
  }

  // ── Confirmar pago con comprobante ────────────────────────
  Future<bool> confirmarPago({
    required String    token,
    required String    pagoId,
    required String    metodo,
    String?            referencia,
    File?              comprobanteFile,
    Uint8List?         comprobanteBytes,
    String?            comprobanteNombre,
  }) async {
    try {
      final uri     = Uri.parse('$baseUrl/pagos/$pagoId/confirmar');
      final request = http.MultipartRequest('PATCH', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['metodo'] = metodo;
      if (referencia != null && referencia.isNotEmpty) {
        request.fields['referencia'] = referencia;
      }

      // Comprobante opcional
      if (kIsWeb && comprobanteBytes != null && comprobanteNombre != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'comprobante', comprobanteBytes, filename: comprobanteNombre,
        ));
      } else if (!kIsWeb && comprobanteFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('comprobante', comprobanteFile.path),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      print('✅ Status confirmar pago: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error confirmando pago: $e');
      return false;
    }
  }

  // ── Mis pagos (historial) ─────────────────────────────────
  Future<List<PagoModel>> getMisPagos(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pagos/mis-pagos'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => PagoModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error mis pagos: $e');
      return [];
    }
  }
}