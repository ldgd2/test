import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/environment.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para cada campo del service.py
  final TextEditingController _nombresController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Rol por defecto (debe ser uno de los ROLES_VALIDOS del backend)
  String _rolSeleccionado = 'cliente'; 
  bool _isLoading = false;

  Future<void> _registrarUsuario() async {
    setState(() => _isLoading = true);

    try {
      // URL basada en tu Swagger: /api/usuarios/registro
      final url =  Uri.parse('${Environment.baseUrl}/usuarios/registro');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "nombres": _nombresController.text.trim(),
          "apellidos": _apellidosController.text.trim(),
          "email": _emailController.text.trim(),
          "telefono": _telefonoController.text.trim(),
          "password": _passwordController.text.trim(),
          "tipo": _rolSeleccionado, // 'cliente', 'admin' o 'tecnico'
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarAlerta("Usuario registrado con éxito", esExito: true);
        // Limpiar campos o volver al login
        Navigator.pop(context); 
      } else {
        final errorData = jsonDecode(response.body);
        _mostrarAlerta(errorData['detail'] ?? "Error al registrar", esExito: false);
      }
    } catch (e) {
      _mostrarAlerta("Error de conexión con el servidor", esExito: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarAlerta(String mensaje, {required bool esExito}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esExito ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Usuario")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.person_add, size: 70, color: Colors.indigo),
            const SizedBox(height: 20),
            
            // Campo Nombres
            _buildTextField(_nombresController, "Nombres", Icons.person),
            const SizedBox(height: 15),
            
            // Campo Apellidos
            _buildTextField(_apellidosController, "Apellidos", Icons.person_outline),
            const SizedBox(height: 15),
            
            // Campo Email
            _buildTextField(_emailController, "Correo electrónico", Icons.email, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 15),

            // Campo Teléfono
            _buildTextField(_telefonoController, "Teléfono", Icons.phone, keyboard: TextInputType.phone),
            const SizedBox(height: 15),
            
            // Campo Password
            _buildTextField(_passwordController, "Contraseña", Icons.lock, obscure: true),
            const SizedBox(height: 15),

            // Selector de Rol (Tipo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _rolSeleccionado,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'cliente', child: Text("Cliente")),
                    DropdownMenuItem(value: 'admin', child: Text("Administrador")),
                    DropdownMenuItem(value: 'tecnico', child: Text("Técnico")),
                  ],
                  onChanged: (value) => setState(() => _rolSeleccionado = value!),
                ),
              ),
            ),
            
            const SizedBox(height: 30),

            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _registrarUsuario,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("GUARDAR REGISTRO", style: TextStyle(color: Colors.white)),
                ),
          ],
        ),
      ),
    );
  }

  // Helper para no repetir código de TextFields
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}