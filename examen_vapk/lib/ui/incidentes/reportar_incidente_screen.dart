import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../data/modules/incidentes/incidente_service.dart';
import '../../data/modules/vehiculos/vehicle_model.dart';
import '../../data/modules/vehiculos/vehicle_service.dart';

class ReportarIncidenteScreen extends StatefulWidget {
  final String token;
  const ReportarIncidenteScreen({super.key, required this.token});

  @override
  State<ReportarIncidenteScreen> createState() => _ReportarIncidenteScreenState();
}

class _ReportarIncidenteScreenState extends State<ReportarIncidenteScreen> {
  // ── Servicios ──────────────────────────────────────────
  final _incidenteService = IncidenteService();
  final _vehiculoService  = VehicleService();
  final _picker           = ImagePicker();
  final _speech           = stt.SpeechToText();

  // ── Controllers ────────────────────────────────────────
  final _descripcionCtrl  = TextEditingController();
  final _direccionCtrl    = TextEditingController();

  // ── Estado ─────────────────────────────────────────────
  List<VehicleModel> _vehiculos        = [];
  VehicleModel?      _vehiculoSeleccionado;
  String             _categoria        = 'incierto';
  bool               _isLoading        = false;
  bool               _cargandoVehiculos = true;

  // GPS
  double?            _lat;
  double?            _lng;
  bool               _obtenendoUbicacion = false;

  // Voz
  bool               _escuchando        = false;
  bool               _speechDisponible  = false;

  // Foto
  XFile?             _fotoXFile;
  Uint8List?         _fotoBytes;
  File?              _fotoFile;

  // Resultado IA
  Map<String, dynamic>? _resultadoIA;

  // ── Categorías ─────────────────────────────────────────
  final List<Map<String, dynamic>> _categorias = [
    {'valor': 'bateria',           'label': 'Batería',         'icono': Icons.battery_alert,      'color': Colors.orange},
    {'valor': 'llanta',            'label': 'Llanta',          'icono': Icons.tire_repair,         'color': Colors.blue},
    {'valor': 'motor',             'label': 'Motor',           'icono': Icons.settings,            'color': Colors.red},
    {'valor': 'sobrecalentamiento','label': 'Sobrecalent.',    'icono': Icons.thermostat,          'color': Colors.deepOrange},
    {'valor': 'choque',            'label': 'Choque',          'icono': Icons.car_crash,           'color': Colors.red},
    {'valor': 'llave_perdida',     'label': 'Llave perdida',   'icono': Icons.vpn_key_off,         'color': Colors.purple},
    {'valor': 'llave_adentro',     'label': 'Llave adentro',   'icono': Icons.lock,                'color': Colors.indigo},
    {'valor': 'incierto',          'label': 'No sé qué es',    'icono': Icons.help_outline,        'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
    _inicializarSpeech();
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  // ── Cargar vehículos ────────────────────────────────────
  Future<void> _cargarVehiculos() async {
    final lista = await _vehiculoService.listarMisVehiculos(widget.token);
    if (!mounted) return;
    setState(() {
      _vehiculos         = lista;
      _cargandoVehiculos = false;
      if (lista.isNotEmpty) _vehiculoSeleccionado = lista.first;
    });
  }

  // ── GPS ─────────────────────────────────────────────────
  Future<void> _obtenerUbicacion() async {
  setState(() => _obtenendoUbicacion = true);
  try {
    // ── WEB ──────────────────────────────────────────────
    if (kIsWeb) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _direccionCtrl.text =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      });
      _mostrarSnack('✅ Ubicación obtenida', esExito: true);
      return;
    }

    // ── MÓVIL ─────────────────────────────────────────────
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _mostrarSnack('Activa el GPS de tu dispositivo', esExito: false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _mostrarSnack('Permiso de ubicación denegado', esExito: false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _mostrarSnack('Permiso denegado permanentemente. Ve a Ajustes.', esExito: false);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _direccionCtrl.text =
          '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
    });
    _mostrarSnack('✅ Ubicación obtenida correctamente', esExito: true);

  } catch (e) {
    _mostrarSnack('Error al obtener ubicación: $e', esExito: false);
  } finally {
    if (mounted) setState(() => _obtenendoUbicacion = false);
  }
}

  // ── Speech to Text ──────────────────────────────────────
  Future<void> _inicializarSpeech() async {
    final disponible = await _speech.initialize(
      onError: (e) => print('Speech error: $e'),
    );
    if (mounted) setState(() => _speechDisponible = disponible);
  }

  Future<void> _toggleEscuchar() async {
    if (!_speechDisponible) {
      _mostrarSnack('Reconocimiento de voz no disponible', esExito: false);
      return;
    }

    if (_escuchando) {
      await _speech.stop();
      setState(() => _escuchando = false);
    } else {
      setState(() => _escuchando = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _descripcionCtrl.text = result.recognizedWords;
            if (result.finalResult) _escuchando = false;
          });
        },
        localeId: 'es_ES',
      );
    }
  }

  // ── Foto ────────────────────────────────────────────────
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
              const Text('Foto de la emergencia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (!kIsWeb)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text('Tomar foto ahora'),
                  onTap: () { Navigator.pop(context); _tomarFoto(ImageSource.camera); },
                ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Elegir de galería'),
                onTap: () { Navigator.pop(context); _tomarFoto(ImageSource.gallery); },
              ),
              if (_fotoXFile != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  title: const Text('Eliminar foto'),
                  onTap: () {
                    setState(() { _fotoXFile = null; _fotoBytes = null; _fotoFile = null; });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tomarFoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);
    if (picked == null) return;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() { _fotoXFile = picked; _fotoBytes = bytes; });
    } else {
      setState(() { _fotoXFile = picked; _fotoFile = File(picked.path); });
    }
  }

  // ── Enviar ──────────────────────────────────────────────
  Future<void> _enviarIncidente() async {
    if (_vehiculoSeleccionado == null) {
      _mostrarSnack('Selecciona un vehículo', esExito: false); return;
    }
    if (_descripcionCtrl.text.trim().isEmpty) {
      _mostrarSnack('Describe el problema', esExito: false); return;
    }
    if (_lat == null || _lng == null) {
      _mostrarSnack('Obtén tu ubicación GPS primero', esExito: false); return;
    }

    setState(() { _isLoading = true; _resultadoIA = null; });

    final incidente = await _incidenteService.reportarIncidente(
      token:             widget.token,
      vehiculoId:        _vehiculoSeleccionado!.id!,
      categoria:         _categoria,
      descripcionManual: _descripcionCtrl.text.trim(),
      direccionTexto:    _direccionCtrl.text.trim(),
      ubicacion:         '$_lat,$_lng',
      fotoFile:          _fotoFile,
      fotoBytes:         _fotoBytes,
      fotoNombre:        _fotoXFile?.name,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (incidente != null) {
      // Mostrar resultado de la IA
      setState(() {
        _resultadoIA = {
          'resumen_ia':        incidente.resumenIa,
          'confianza_ia':      incidente.confianzaIa,
          'prioridad':         incidente.prioridad,
          'requiere_revision': incidente.requiereRevision,
        };
      });
      _mostrarDialogoExito(incidente);
    } else {
      _mostrarSnack('❌ Error al enviar el reporte', esExito: false);
    }
  }

  void _mostrarDialogoExito(incidente) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 8),
            Text('¡Reporte enviado!', textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Los talleres cercanos fueron notificados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            if (incidente.resumenIa != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
                      const SizedBox(width: 6),
                      const Text('Análisis de IA',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      const Spacer(),
                      if (incidente.confianzaIa != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(incidente.confianzaIa * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text(incidente.resumenIa!,
                        style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Text('Prioridad: ', style: TextStyle(fontSize: 12)),
                      _badgePrioridad(incidente.prioridad ?? 'media'),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgePrioridad(String prioridad) {
    final colores = {
      'baja':    Colors.green,
      'media':   Colors.orange,
      'alta':    Colors.red,
      'critica': Colors.red.shade900,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: (colores[prioridad] ?? Colors.grey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colores[prioridad] ?? Colors.grey),
      ),
      child: Text(
        prioridad.toUpperCase(),
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: colores[prioridad] ?? Colors.grey,
        ),
      ),
    );
  }

  void _mostrarSnack(String msg, {required bool esExito}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: esExito ? Colors.green.shade700 : Colors.red.shade700,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        title: const Text('🚨 Pedir Auxilio', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildCargandoIA()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Alerta roja ──
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tu reporte será enviado a talleres cercanos y analizado por IA.',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Vehículo ──
                  _seccionTitulo('🚗 Tu vehículo'),
                  const SizedBox(height: 8),
                  _cargandoVehiculos
                      ? const Center(child: CircularProgressIndicator())
                      : _vehiculos.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: const Text('No tienes vehículos registrados. Regístralos primero.'),
                            )
                          : DropdownButtonFormField<VehicleModel>(
                              value: _vehiculoSeleccionado,
                              decoration: InputDecoration(
                                border:    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled:    true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.directions_car),
                              ),
                              items: _vehiculos.map((v) => DropdownMenuItem(
                                value: v,
                                child: Text('${v.marca} ${v.modelo} — ${v.placa}'),
                              )).toList(),
                              onChanged: (v) => setState(() => _vehiculoSeleccionado = v),
                            ),
                  const SizedBox(height: 20),

                  // ── Categoría ──
                  _seccionTitulo('⚠️ ¿Qué tipo de problema es?'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount:     4,
                    shrinkWrap:         true,
                    physics:            const NeverScrollableScrollPhysics(),
                    crossAxisSpacing:   8,
                    mainAxisSpacing:    8,
                    childAspectRatio:   0.85,
                    children: _categorias.map((cat) {
                      final seleccionado = _categoria == cat['valor'];
                      return GestureDetector(
                        onTap: () => setState(() => _categoria = cat['valor']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color:        seleccionado
                                          ? (cat['color'] as Color).withOpacity(0.15)
                                          : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(
                              color: seleccionado ? cat['color'] : Colors.grey.shade300,
                              width: seleccionado ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(cat['icono'], color: cat['color'], size: 28),
                              const SizedBox(height: 4),
                              Text(
                                cat['label'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize:   10,
                                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                                  color:      seleccionado ? cat['color'] : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Descripción + Micrófono ──
                  _seccionTitulo('🎤 Describe el problema'),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      TextFormField(
                        controller:  _descripcionCtrl,
                        maxLines:    4,
                        decoration: InputDecoration(
                          hintText:   'Describe qué pasó con tu vehículo...\nPuedes usar el micrófono 🎤',
                          border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled:     true,
                          fillColor:  Colors.white,
                          contentPadding: const EdgeInsets.fromLTRB(16, 16, 60, 16),
                        ),
                      ),
                      Positioned(
                        right:  8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: _toggleEscuchar,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:  _escuchando ? Colors.red : Colors.indigo,
                              shape:  BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:   (_escuchando ? Colors.red : Colors.indigo).withOpacity(0.4),
                                  blurRadius: 8, spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _escuchando ? Icons.stop : Icons.mic,
                              color: Colors.white, size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_escuchando)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.graphic_eq, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Text('Escuchando...', style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                      ]),
                    ),
                  const SizedBox(height: 20),

                  // ── Ubicación GPS ──
                  _seccionTitulo('📍 Tu ubicación'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _direccionCtrl,
                        readOnly:   true,
                        decoration: InputDecoration(
                          hintText:   'Presiona el botón para obtener GPS',
                          border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled:     true,
                          fillColor:  _lat != null ? Colors.green.shade50 : Colors.white,
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: _lat != null ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _obtenendoUbicacion ? null : _obtenerUbicacion,
                        child: _obtenendoUbicacion
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ]),
                  if (_lat != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'GPS: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 20),

                  // ── Foto ──
                  _seccionTitulo('📷 Foto de la emergencia (opcional)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _mostrarOpcionesFoto,
                    child: Container(
                      width:  double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _fotoXFile != null ? Colors.indigo : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: _fotoXFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: kIsWeb
                                  ? Image.memory(_fotoBytes!, fit: BoxFit.cover, width: double.infinity)
                                  : Image.file(_fotoFile!,   fit: BoxFit.cover, width: double.infinity),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('Toca para agregar foto',
                                    style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Botón enviar ──
                  SizedBox(
                    width:  double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon:  const Icon(Icons.send),
                      label: const Text(
                        'ENVIAR REPORTE DE AUXILIO',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _enviarIncidente,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ── Pantalla cargando IA ─────────────────────────────────
  Widget _buildCargandoIA() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:        Colors.purple.shade50,
              shape:        BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 60, color: Colors.purple),
          ),
          const SizedBox(height: 24),
          const Text('Enviando reporte...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('La IA está analizando tu caso', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Colors.purple),
          const SizedBox(height: 16),
          Text('Notificando talleres cercanos...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _seccionTitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}