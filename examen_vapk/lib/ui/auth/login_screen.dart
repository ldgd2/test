import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_screen.dart';
import '../../main.dart';
import '../../core/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _isLoading      = false;
  bool  _obscurePass    = true;

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Por favor llena todos los campos', esExito: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://185.214.134.23:8000/api/usuarios/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token     = data['access_token'] as String;
        final usuario   = data['usuario'];
        final nombre    = usuario?['nombres']?.toString()    ?? 'Usuario';
        final tipo      = usuario?['tipo']?.toString()       ?? 'cliente';
        final usuarioId = usuario?['id']?.toString()         ?? '';
        // ── FCM: guardar token del dispositivo ──────────────
        final fcmToken = await FirebaseService.obtenerToken();
        if (fcmToken != null) {
          await http.post(
            Uri.parse('http://185.214.134.23:8000/api/usuarios/fcm-token'),
            headers: {
              'Content-Type':  'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'fcm_token': fcmToken}),
          );
        }
        


        _snack('¡Bienvenido $nombre!', esExito: true);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              token:     token,
              nombre:    nombre,
              tipo:      tipo,
              usuarioId: usuarioId,   // ← para WebSocket
            ),
          ),
        );
      } else {
        String msg = 'Error al ingresar';
        if (data['detail'] is String) msg = data['detail'];
        else if (data['detail'] is List) msg = data['detail'][0]['msg'] ?? msg;
        _snack(msg, esExito: false);
      }
    } catch (e) {
      _snack('Error de conexión con el servidor', esExito: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {required bool esExito}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg, textAlign: TextAlign.center),
      backgroundColor: esExito ? Colors.green.shade800 : Colors.red.shade800,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.indigo.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.car_repair, size: 80, color: Colors.indigo),
              ),
              const SizedBox(height: 16),
              const Text('AutoAsistencia',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const Text('Plataforma de emergencias vehiculares',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 40),

              TextField(
                controller:   _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText:  'Correo electrónico',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true, fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller:  _passwordCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText:  'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true, fillColor: Colors.grey.shade50,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              _isLoading
                  ? const CircularProgressIndicator()
                  : Column(children: [
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          child: const Text('INICIAR SESIÓN',
                              style: TextStyle(color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text('¿No tienes cuenta? Regístrate aquí',
                            style: TextStyle(color: Colors.indigo,
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ]),
            ],
          ),
        ),
      ),
    );
  }
}