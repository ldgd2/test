class Environment {
  // ── Configuración del Servidor ─────────────────────────────────────
  // Cambia esta IP cuando el servidor se mueva de producción
  static const String apiIp = "185.214.134.23";
  static const String apiPort = "8000";
  
  // URL base para las peticiones REST
  static const String baseUrl = "http://$apiIp:$apiPort/api";

  // URL base para WebSockets (notificaciones en tiempo real)
  static const String wsBaseUrl = "ws://$apiIp:$apiPort/api";
  
  // URL base para archivos estáticos (fotos, logos, etc)
  static const String staticUrl = "http://$apiIp:$apiPort/static";
}
