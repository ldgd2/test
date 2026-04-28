import 'package:flutter/material.dart';
import '../../data/modules/notificaciones/notificacion_model.dart';
import '../../data/modules/notificaciones/notificacion_service.dart';
import '../pagos/pago_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  final String token;
  final String usuarioId;

  const NotificacionesScreen({
    super.key,
    required this.token,
    required this.usuarioId,
  });

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _service = NotificacionService();
  List<NotificacionModel> _notificaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _escucharWebSocket();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    final lista = await _service.getMisNotificaciones(widget.token, widget.usuarioId);
    if (!mounted) return;
    setState(() { _notificaciones = lista; _cargando = false; });
  }

  void _escucharWebSocket() {
    _service.conectar(widget.usuarioId);
    _service.notificacionesStream.listen((data) {
      if (!mounted) return;
      final nueva = NotificacionModel(
        id:         data['notif_id'] ?? DateTime.now().toString(),
        titulo:     data['titulo']   ?? '',
        cuerpo:     data['cuerpo']   ?? '',
        leida:      false,
        createdAt:  DateTime.now().toIso8601String(),
        datosExtra: data['datos_extra'],
      );
      setState(() => _notificaciones.insert(0, nueva));
    });
  }

  // ── Ir a pantalla de pago ─────────────────────────────────
  void _irAPago(NotificacionModel notif) {
    final asignacionId = notif.datosExtra?['asignacion_id']?.toString() ?? '';
    final monto        = double.tryParse(notif.datosExtra?['monto']?.toString() ?? '0') ?? 0;
    final taller       = notif.datosExtra?['taller']?.toString() ?? '';

    if (asignacionId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PagoScreen(
          token:         widget.token,
          asignacionId:  asignacionId,
          montoInicial:  monto,
          tallerNombre:  taller,
        ),
      ),
    );
  }

  void _marcarLeida(NotificacionModel notif) {
    if (notif.leida) return;
    _service.marcarLeida(notif.id, widget.token);
    final i = _notificaciones.indexOf(notif);
    if (i < 0) return;
    setState(() {
      _notificaciones[i] = NotificacionModel(
        id:         notif.id,
        titulo:     notif.titulo,
        cuerpo:     notif.cuerpo,
        leida:      true,
        createdAt:  notif.createdAt,
        datosExtra: notif.datosExtra,
      );
    });
  }

  Map<String, dynamic> _configEvento(String evento) {
    switch (evento) {
      case 'aceptado':      return {'color': Colors.indigo,        'emoji': '✅'};
      case 'en_camino':     return {'color': Colors.blue,          'emoji': '🚗'};
      case 'pago_pendiente':return {'color': Colors.green.shade700,'emoji': '💳'};
      default:              return {'color': Colors.grey.shade700,  'emoji': '🔔'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (_notificaciones.where((n) => !n.leida).isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text(
                '${_notificaciones.where((n) => !n.leida).length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarHistorial),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _notificaciones.isEmpty
              ? _buildVacio()
              : ListView.builder(
                  padding:   const EdgeInsets.all(16),
                  itemCount: _notificaciones.length,
                  itemBuilder: (context, index) => _buildTarjeta(_notificaciones[index]),
                ),
    );
  }

  Widget _buildTarjeta(NotificacionModel notif) {
    final evento = notif.datosExtra?['evento'] ?? '';
    final config = _configEvento(evento);

    return Card(
      margin:    const EdgeInsets.only(bottom: 12),
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: notif.leida ? 1 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _marcarLeida(notif);
          if (evento == 'pago_pendiente') _irAPago(notif);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícono
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color:        (config['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(config['emoji'], style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(notif.titulo,
                            style: TextStyle(
                              fontWeight: notif.leida ? FontWeight.normal : FontWeight.bold,
                              fontSize: 15,
                            )),
                      ),
                      if (!notif.leida)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(notif.cuerpo,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),

                    // Info extra según evento
                    if (evento == 'aceptado' && notif.datosExtra != null) ...[
                      const SizedBox(height: 6),
                      _infoChip('🧑‍🔧 ${notif.datosExtra!['tecnico'] ?? ''}'),
                      _infoChip('🏪 ${notif.datosExtra!['taller'] ?? ''}'),
                      _infoChip('⏱ ${notif.datosExtra!['tiempo_min'] ?? 0} min aprox.'),
                    ],

                    if (evento == 'en_camino' && notif.datosExtra != null) ...[
                      const SizedBox(height: 6),
                      _infoChip('⏱ Llega en ~${notif.datosExtra!['tiempo_min'] ?? 0} minutos'),
                    ],

                    // Botón pagar
                    if (evento == 'pago_pendiente') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon:  const Icon(Icons.payment, size: 16),
                          label: Text(
                            'VER COBRO — Bs ${notif.datosExtra?['monto']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _irAPago(notif),
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),
                    Text(_formatFecha(notif.createdAt),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    );
  }

  Widget _buildVacio() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 72, color: Colors.grey),
          SizedBox(height: 12),
          Text('Sin notificaciones aún', style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 4),
          Text('Aquí verás el estado de tu auxilio en tiempo real',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return fecha; }
  }
}