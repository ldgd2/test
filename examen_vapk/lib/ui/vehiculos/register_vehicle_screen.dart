import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/modules/vehiculos/vehicle_model.dart';
import '../../data/modules/vehiculos/vehicle_service.dart';

class RegisterVehicleScreen extends StatefulWidget {
  final String token;
  const RegisterVehicleScreen({super.key, required this.token});

  @override
  State<RegisterVehicleScreen> createState() => _RegisterVehicleScreenState();
}

class _RegisterVehicleScreenState extends State<RegisterVehicleScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _service    = VehicleService();
  final _picker     = ImagePicker();

  // Controllers
  final _placaCtrl  = TextEditingController();
  final _marcaCtrl  = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl   = TextEditingController();
  final _colorCtrl  = TextEditingController();

  String     _combustible = 'gasolina';
  bool       _isLoading   = false;

  // Foto del vehículo
  XFile?     _fotoXFile;    // para web y móvil
  Uint8List? _fotoBytes;    // para mostrar en web
  File?      _fotoFile;     // para móvil

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  // ── Seleccionar foto ──────────────────────────────────────
  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source:    source,
        imageQuality: 80,
        maxWidth:  800,
      );
      if (picked == null) return;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _fotoXFile  = picked;
          _fotoBytes  = bytes;
        });
      } else {
        setState(() {
          _fotoXFile = picked;
          _fotoFile  = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarSnack("Error al seleccionar imagen: $e", esExito: false);
    }
  }

  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Foto del vehículo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Cámara — solo en móvil
              if (!kIsWeb)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text('Tomar foto'),
                  subtitle: const Text('Usar la cámara del dispositivo'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarFoto(ImageSource.camera);
                  },
                ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Elegir de galería'),
                subtitle: const Text('Seleccionar una imagen existente'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFoto(ImageSource.gallery);
                },
              ),
              if (_fotoXFile != null) ...[
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  title: const Text('Eliminar foto'),
                  onTap: () {
                    setState(() {
                      _fotoXFile = null;
                      _fotoBytes = null;
                      _fotoFile  = null;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nuevoVehiculo = VehicleModel(
      placa:       _placaCtrl.text.trim().toUpperCase(),
      marca:       _marcaCtrl.text.trim(),
      modelo:      _modeloCtrl.text.trim(),
      anio:        int.parse(_anioCtrl.text.trim()),
      color:       _colorCtrl.text.trim(),
      combustible: _combustible,
    );

    final resultado = await _service.registrarVehiculo(
      nuevoVehiculo,
      widget.token,
      fotoFile:  _fotoFile,
      fotoBytes: _fotoBytes,
      fotoNombre: _fotoXFile?.name,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (resultado != null) {
      _mostrarSnack("✅ Vehículo registrado con éxito", esExito: true);
      Navigator.pop(context);
    } else {
      _mostrarSnack("❌ Error al registrar. Revisa los datos.", esExito: false);
    }
  }

  void _mostrarSnack(String msg, {required bool esExito}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: esExito ? Colors.green.shade700 : Colors.red.shade700,
        behavior:        SnackBarBehavior.floating,
        margin:          const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Widget foto ───────────────────────────────────────────
  Widget _buildFotoWidget() {
    return GestureDetector(
      onTap: _mostrarOpcionesFoto,
      child: Container(
        width:  double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color:        Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _fotoXFile != null ? Colors.indigo : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: _fotoXFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.memory(_fotoBytes!, fit: BoxFit.cover, width: double.infinity)
                    : Image.file(_fotoFile!,   fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    'Toca para agregar foto del vehículo',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opcional',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text(
          'Registrar Vehículo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Foto del vehículo ──
              const Text(
                'Foto del vehículo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildFotoWidget(),
              if (_fotoXFile != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _fotoXFile!.name,
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // ── Datos del vehículo ──
              const Text(
                'Datos del vehículo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _buildInput(_placaCtrl, "Placa", Icons.directions_car, hint: "Ej: 1234ABC"),
                      const SizedBox(height: 14),
                      _buildInput(_marcaCtrl, "Marca", Icons.factory, hint: "Ej: Toyota"),
                      const SizedBox(height: 14),
                      _buildInput(_modeloCtrl, "Modelo", Icons.model_training, hint: "Ej: Corolla"),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput(
                              _anioCtrl, "Año", Icons.calendar_today,
                              hint: "2020", isNumber: true,
                              extraValidator: (val) {
                                final n = int.tryParse(val ?? '');
                                if (n == null) return 'Inválido';
                                if (n < 1900 || n > 2100) return '1900-2100';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInput(
                              _colorCtrl, "Color", Icons.palette,
                              hint: "Blanco", required: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _combustible,
                        decoration: InputDecoration(
                          labelText:  "Combustible",
                          prefixIcon: const Icon(Icons.local_gas_station),
                          border:     const OutlineInputBorder(),
                          filled:     true,
                          fillColor:  Colors.grey.shade50,
                        ),
                        items: ["gasolina", "diesel", "electrico", "hibrido", "gas"]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e[0].toUpperCase() + e.substring(1)),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _combustible = val!),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Botón guardar ──
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width:  double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon:  const Icon(Icons.save_alt),
                        label: const Text(
                          "GUARDAR VEHÍCULO",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _submit,
                      ),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String?  hint,
    bool     isNumber  = false,
    bool     required  = true,
    String? Function(String?)? extraValidator,
  }) {
    return TextFormField(
      controller:   ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: Icon(icon),
        border:     const OutlineInputBorder(),
        filled:     true,
        fillColor:  Colors.grey.shade50,
      ),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) return "Campo requerido";
        if (extraValidator != null) return extraValidator(value);
        return null;
      },
    );
  }
}