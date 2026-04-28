import 'package:flutter/material.dart';
import '../../data/modules/vehiculos/vehicle_model.dart';
import '../../data/modules/vehiculos/vehicle_service.dart';
import 'register_vehicle_screen.dart';

class DetalleVehiculoScreen extends StatefulWidget {
  final VehicleModel vehiculo;
  final String       token;

  const DetalleVehiculoScreen({
    super.key,
    required this.vehiculo,
    required this.token,
  });

  @override
  State<DetalleVehiculoScreen> createState() => _DetalleVehiculoScreenState();
}

class _DetalleVehiculoScreenState extends State<DetalleVehiculoScreen> {
  final _service = VehicleService();
  bool _eliminando = false;

  // ── Confirmar eliminación ──────────────────────────────
  Future<void> _confirmarEliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text('Eliminar vehículo'),
        ]),
        content: Text(
          '¿Estás seguro de eliminar el ${widget.vehiculo.marca} '
          '${widget.vehiculo.modelo} (${widget.vehiculo.placa})?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _eliminando = true);

    final ok = await _service.eliminarVehiculo(
      widget.vehiculo.id!, widget.token,
    );

    if (!mounted) return;
    setState(() => _eliminando = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         const Text('✅ Vehículo eliminado'),
          backgroundColor: Colors.green.shade700,
          behavior:        SnackBarBehavior.floating,
          margin:          const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true); // true = hubo cambios
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         const Text('❌ Error al eliminar'),
          backgroundColor: Colors.red.shade700,
          behavior:        SnackBarBehavior.floating,
          margin:          const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Ir a editar ────────────────────────────────────────
  Future<void> _irAEditar() async {
    final actualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarVehiculoScreen(
          vehiculo: widget.vehiculo,
          token:    widget.token,
        ),
      ),
    );
    if (actualizado == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  // ── Color del combustible ──────────────────────────────
  Color _colorCombustible(String c) {
    switch (c.toLowerCase()) {
      case 'gasolina':  return Colors.orange;
      case 'diesel':    return Colors.brown;
      case 'electrico': return Colors.green;
      case 'hibrido':   return Colors.teal;
      case 'gas':       return Colors.blue;
      default:          return Colors.grey;
    }
  }

  IconData _iconoCombustible(String c) {
    switch (c.toLowerCase()) {
      case 'electrico': return Icons.electric_bolt;
      case 'hibrido':   return Icons.eco;
      default:          return Icons.local_gas_station;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehiculo;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Text('${v.marca} ${v.modelo}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon:    const Icon(Icons.edit),
            tooltip: 'Editar',
            onPressed: _irAEditar,
          ),
          IconButton(
            icon:    const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            onPressed: _eliminando ? null : _confirmarEliminar,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            // ── Foto / Avatar grande ──
            Container(
              width:  double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color:        Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: Colors.indigo.shade100),
              ),
              child: v.fotoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        'http://185.214.134.23:8000/${v.fotoUrl}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarDefault(),
                      ),
                    )
                  : _avatarDefault(),
            ),
            const SizedBox(height: 20),

            // ── Placa destacada ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color:        Colors.indigo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                v.placa,
                style: const TextStyle(
                  color:       Colors.white,
                  fontSize:    28,
                  fontWeight:  FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Tarjeta de datos ──
            Card(
              shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _fila(Icons.factory,         'Marca',   v.marca),
                    _divider(),
                    _fila(Icons.model_training,  'Modelo',  v.modelo),
                    _divider(),
                    _fila(Icons.calendar_today,  'Año',     v.anio.toString()),
                    _divider(),
                    _fila(Icons.palette,         'Color',   v.color ?? 'No especificado'),
                    _divider(),
                    // Combustible con badge de color
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Icon(_iconoCombustible(v.combustible),
                            color: _colorCombustible(v.combustible), size: 22),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text('Combustible',
                              style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color:        _colorCombustible(v.combustible)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border:       Border.all(
                                color: _colorCombustible(v.combustible)
                                    .withOpacity(0.4)),
                          ),
                          child: Text(
                            v.combustible.toUpperCase(),
                            style: TextStyle(
                              color:      _colorCombustible(v.combustible),
                              fontWeight: FontWeight.bold,
                              fontSize:   13,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Botón editar ──
            SizedBox(
              width:  double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon:  const Icon(Icons.edit),
                label: const Text('EDITAR VEHÍCULO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _irAEditar,
              ),
            ),
            const SizedBox(height: 12),

            // ── Botón eliminar ──
            SizedBox(
              width:  double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                icon:  _eliminando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                  _eliminando ? 'Eliminando...' : 'ELIMINAR VEHÍCULO',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  side:  const BorderSide(color: Colors.red, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _eliminando ? null : _confirmarEliminar,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _avatarDefault() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.directions_car, size: 80, color: Colors.indigo.shade200),
        const SizedBox(height: 8),
        Text('Sin foto',
            style: TextStyle(color: Colors.indigo.shade300, fontSize: 14)),
      ],
    );
  }

  Widget _fila(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icono, color: Colors.indigo, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ),
        Text(valor,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey.shade200);
}


// ══════════════════════════════════════════════════════════════════════════
// PANTALLA EDITAR VEHÍCULO
// ══════════════════════════════════════════════════════════════════════════
class EditarVehiculoScreen extends StatefulWidget {
  final VehicleModel vehiculo;
  final String       token;

  const EditarVehiculoScreen({
    super.key,
    required this.vehiculo,
    required this.token,
  });

  @override
  State<EditarVehiculoScreen> createState() => _EditarVehiculoScreenState();
}

class _EditarVehiculoScreenState extends State<EditarVehiculoScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _service    = VehicleService();

  late final TextEditingController _placaCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _anioCtrl;
  late final TextEditingController _colorCtrl;
  late String _combustible;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final v    = widget.vehiculo;
    _placaCtrl  = TextEditingController(text: v.placa);
    _marcaCtrl  = TextEditingController(text: v.marca);
    _modeloCtrl = TextEditingController(text: v.modelo);
    _anioCtrl   = TextEditingController(text: v.anio.toString());
    _colorCtrl  = TextEditingController(text: v.color ?? '');
    _combustible = v.combustible;
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final actualizado = VehicleModel(
      id:          widget.vehiculo.id,
      placa:       _placaCtrl.text.trim().toUpperCase(),
      marca:       _marcaCtrl.text.trim(),
      modelo:      _modeloCtrl.text.trim(),
      anio:        int.parse(_anioCtrl.text.trim()),
      color:       _colorCtrl.text.trim(),
      combustible: _combustible,
    );

    final ok = await _service.actualizarVehiculo(
        actualizado, widget.token);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         const Text('✅ Vehículo actualizado'),
          backgroundColor: Colors.green.shade700,
          behavior:        SnackBarBehavior.floating,
          margin:          const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         const Text('❌ Error al actualizar'),
          backgroundColor: Colors.red.shade700,
          behavior:        SnackBarBehavior.floating,
          margin:          const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text('Editar Vehículo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _campo(_placaCtrl,  'Placa',  Icons.directions_car),
                      const SizedBox(height: 14),
                      _campo(_marcaCtrl,  'Marca',  Icons.factory),
                      const SizedBox(height: 14),
                      _campo(_modeloCtrl, 'Modelo', Icons.model_training),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: _campo(_anioCtrl, 'Año',
                              Icons.calendar_today, isNumber: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campo(_colorCtrl, 'Color',
                              Icons.palette, required: false),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _combustible,
                        decoration: InputDecoration(
                          labelText:  'Combustible',
                          prefixIcon: const Icon(Icons.local_gas_station),
                          border:     const OutlineInputBorder(),
                          filled:     true,
                          fillColor:  Colors.grey.shade50,
                        ),
                        items: ['gasolina', 'diesel', 'electrico', 'hibrido', 'gas']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                      e[0].toUpperCase() + e.substring(1)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _combustible = v!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width:  double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon:  const Icon(Icons.save),
                        label: const Text('GUARDAR CAMBIOS',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _guardar,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icono, {
    bool isNumber = false,
    bool required = true,
  }) {
    return TextFormField(
      controller:   ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icono),
        border:     const OutlineInputBorder(),
        filled:     true,
        fillColor:  Colors.grey.shade50,
      ),
      validator: (v) {
        if (required && (v == null || v.isEmpty)) return 'Requerido';
        return null;
      },
    );
  }
}