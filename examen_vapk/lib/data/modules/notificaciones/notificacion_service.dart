import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../../../core/environment.dart';
import 'notificacion_model.dart';

class NotificacionService {
  final String baseUrl   = Environment.baseUrl;
  final String wsBaseUrl = Environment.wsBaseUrl;

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _streamController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get notificacionesStream =>
      _streamController.stream;

  // ══════════════════════════════════════════════════════
  // CONECTAR WEBSOCKET
  // ══════════════════════════════════════════════════════
  void conectar(String usuarioId) {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsBaseUrl/notificaciones/ws/$usuarioId'),
      );

      _channel!.stream.listen(
        (mensaje) {
          try {
            final data = jsonDecode(mensaje as String);
            _streamController.add(data);
          } catch (e) {
            print('❌ Error parseando WebSocket: $e');
          }
        },
        onError: (e) => print('❌ WebSocket error: $e'),
        onDone:  ()  => print('🔌 WebSocket desconectado'),
      );

      print('✅ WebSocket conectado para usuario: $usuarioId');
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
    }
  }

  void desconectar() {
    _channel?.sink.close();
    _channel = null;
  }

  // ══════════════════════════════════════════════════════
  // OBTENER NOTIFICACIONES HISTORIAL
  // ══════════════════════════════════════════════════════
  Future<List<NotificacionModel>> getMisNotificaciones(
      String token, String usuarioId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notificaciones/mis-notificaciones?usuario_id=$usuarioId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => NotificacionModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error notificaciones: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════
  // MARCAR COMO LEÍDA
  // ══════════════════════════════════════════════════════
  Future<void> marcarLeida(String notifId, String token) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/notificaciones/$notifId/leida'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      print('❌ Error marcando leída: $e');
    }
  }

  void dispose() {
    desconectar();
    _streamController.close();
  }
}