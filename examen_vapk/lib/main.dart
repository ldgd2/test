import 'package:flutter/material.dart';
import 'ui/auth/login_screen.dart';
import 'ui/vehiculos/register_vehicle_screen.dart';
import 'ui/vehiculos/detalle_vehiculo_screen.dart';
import 'ui/notificaciones/notificaciones_screen.dart';
import 'ui/incidentes/reportar_incidente_screen.dart';
import 'data/modules/vehiculos/vehicle_model.dart';
import 'data/modules/vehiculos/vehicle_service.dart';
import 'data/modules/notificaciones/notificacion_service.dart';
import 'core/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.inicializar();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                     'AutoAsistencia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// DASHBOARD
// ══════════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  final String token;
  final String nombre;
  final String tipo;
  final String usuarioId;

  const DashboardScreen({
    super.key,
    required this.token,
    required this.nombre,
    required this.tipo,
    required this.usuarioId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _vehicleService = VehicleService();
  final _notifService   = NotificacionService();
  int   _notifNoLeidas  = 0;

  @override
  void initState() {
    super.initState();
    _conectarWebSocket();
  }

  @override
  void dispose() {
    _notifService.dispose();
    super.dispose();
  }

  // ── WebSocket ─────────────────────────────────────────────
  void _conectarWebSocket() {
    _notifService.conectar(widget.usuarioId);
    _notifService.notificacionesStream.listen((data) {
      if (!mounted) return;
      setState(() => _notifNoLeidas++);
      _mostrarBanner(data);
    });
  }

  void _mostrarBanner(Map<String, dynamic> data) {
    final titulo = data['titulo'] ?? '';
    final cuerpo = data['cuerpo'] ?? '';
    final evento = data['datos_extra']?['evento'] ?? '';

    final colores = {
      'aceptado':       Colors.indigo,
      'en_camino':      Colors.blue,
      'pago_pendiente': Colors.green.shade700,
    };
    final emojis = {
      'aceptado':       '✅',
      'en_camino':      '🚗',
      'pago_pendiente': '💳',
    };

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: colores[evento] ?? Colors.grey.shade800,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text(cuerpo,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        leading: Text(emojis[evento] ?? '🔔',
            style: const TextStyle(fontSize: 28)),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
          if (evento == 'pago_pendiente')
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                _irANotificaciones();
              },
              child: const Text('VER PAGO',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }

  void _irANotificaciones() {
    setState(() => _notifNoLeidas = 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificacionesScreen(
          token:     widget.token,
          usuarioId: widget.usuarioId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text('AutoAsistencia',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // ── Campanita notificaciones ──
          Stack(
            children: [
              IconButton(
                icon:    const Icon(Icons.notifications),
                tooltip: 'Notificaciones',
                onPressed: _irANotificaciones,
              ),
              if (_notifNoLeidas > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$_notifNoLeidas',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header bienvenida ──
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(children: [
              const CircleAvatar(
                backgroundColor: Colors.white24,
                radius: 26,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Hola, ${widget.nombre}!',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text(widget.tipo.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Botón PEDIR AUXILIO ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width:  double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon:  const Icon(Icons.sos, size: 24),
                label: const Text('PEDIR AUXILIO',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReportarIncidenteScreen(token: widget.token),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Botón REGISTRAR VEHÍCULO ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width:  double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon:  const Icon(Icons.add_circle_outline),
                label: const Text('REGISTRAR VEHÍCULO',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RegisterVehicleScreen(token: widget.token),
                    ),
                  );
                  setState(() {});
                },
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Mis Vehículos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // ── Lista vehículos ──
          Expanded(
            child: FutureBuilder<List<VehicleModel>>(
              future: _vehicleService.listarMisVehiculos(widget.token),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red),
                        SizedBox(height: 12),
                        Text('Error al cargar vehículos',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car_outlined,
                            size: 72, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No tienes vehículos registrados',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Presiona el botón de arriba para agregar uno',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:   const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final v = snapshot.data![index];
                    return Card(
                      margin:    const EdgeInsets.only(bottom: 10),
                      shape:     RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          radius: 26,
                          child: const Icon(Icons.directions_car,
                              color: Colors.indigo, size: 28),
                        ),
                        title: Text('${v.marca} ${v.modelo}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('🪪 Placa: ${v.placa}'),
                            Text('🎨 Color: ${v.color ?? "N/A"}  •  📅 ${v.anio}'),
                            Text('⛽ ${v.combustible.toUpperCase()}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey),
                        // ── Navegar al detalle del vehículo ──
                        onTap: () async {
                          final cambio = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetalleVehiculoScreen(
                                vehiculo: v,
                                token:    widget.token,
                              ),
                            ),
                          );
                          if (cambio == true) setState(() {});
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}