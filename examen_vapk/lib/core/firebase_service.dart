import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> inicializar() async {
    await Firebase.initializeApp();

    // Pedir permiso
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
  }

  // Obtener token del dispositivo para enviarlo al backend
  static Future<String?> obtenerToken() async {
    return await _messaging.getToken();
  }

  // Escuchar notificaciones con app abierta
  static void escucharMensajes(Function(String titulo, String cuerpo) onMensaje) {
    FirebaseMessaging.onMessage.listen((message) {
      final titulo = message.notification?.title ?? '';
      final cuerpo = message.notification?.body  ?? '';
      onMensaje(titulo, cuerpo);
    });
  }
}