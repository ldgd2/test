import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/modules/pagos/pago_model.dart';
import '../../data/modules/pagos/pago_service.dart';

class PagoScreen extends StatefulWidget {
  final String token;
  final String asignacionId;
  final String? pagoId;         // si ya tenemos el ID directo
  final double? montoInicial;   // monto de la notificación
  final String? tallerNombre;

  const PagoScreen({
    super.key,
    required this.token,
    required this.asignacionId,
    this.pagoId,
    this.montoInicial,
    this.tallerNombre,
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  final _service    = PagoService();
  final _picker     = ImagePicker();
  final _refCtrl    = TextEditingController();

  PagoModel? _pago;
  bool       _cargando      = true;
  bool       _pagando       = false;
  String     _metodoPago    = 'efectivo';
  bool       _mostrarQR     = false;

  // Comprobante
  XFile?     _comprobanteXFile;
  Uint8List? _comprobanteBytes;
  File?      _comprobanteFile;

  @override
  void initState() {
    super.initState();
    _cargarPago();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPago() async {
    final pago = await _service.getPagoPorAsignacion(
        widget.asignacionId, widget.token);
    if (!mounted) return;
    setState(() {
      _pago     = pago;
      _cargando = false;
      if (pago != null) _metodoPago = pago.metodo;
    });
  }

  // ── Seleccionar comprobante ───────────────────────────────
  Future<void> _seleccionarComprobante() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80,
    );
    if (picked == null) return;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() { _comprobanteXFile = picked; _comprobanteBytes = bytes; });
    } else {
      setState(() { _comprobanteXFile = picked; _comprobanteFile = File(picked.path); });
    }
  }

  // ── Confirmar pago ────────────────────────────────────────
  Future<void> _confirmarPago() async {
    if (_pago == null) return;
    setState(() => _pagando = true);

    final ok = await _service.confirmarPago(
      token:              widget.token,
      pagoId:             _pago!.id,
      metodo:             _metodoPago,
      referencia:         _refCtrl.text.trim(),
      comprobanteFile:    _comprobanteFile,
      comprobanteBytes:   _comprobanteBytes,
      comprobanteNombre:  _comprobanteXFile?.name,
    );

    if (!mounted) return;
    setState(() => _pagando = false);

    if (ok) {
      _mostrarDialogoExito();
    } else {
      _snack('❌ Error al confirmar el pago. Intenta de nuevo.', esExito: false);
    }
  }

  void _mostrarDialogoExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('¡Pago confirmado!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Tu pago de Bs ${_pago!.montoTotal.toStringAsFixed(2)} fue registrado correctamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('El taller fue notificado.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context); // cerrar dialog
                Navigator.pop(context); // volver atrás
              },
              child: const Text('LISTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {required bool esExito}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: esExito ? Colors.green.shade700 : Colors.red.shade700,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('💳 Pagar Servicio',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _pago == null
              ? _buildNoPago()
              : _pago!.estaPagado
                  ? _buildYaPagado()
                  : _buildFormularioPago(),
    );
  }

  // ── Sin pago encontrado ───────────────────────────────────
  Widget _buildNoPago() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No hay cobro disponible aún',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('El técnico aún no ha enviado el formulario de cobro.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Ya está pagado ────────────────────────────────────────
  Widget _buildYaPagado() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              const Text('¡Pago completado!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 4),
              Text('Bs ${_pago!.montoTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.green)),
            ]),
          ),
          const SizedBox(height: 20),
          _buildTarjetaDetalle(),
        ],
      ),
    );
  }

  // ── Formulario de pago ────────────────────────────────────
  Widget _buildFormularioPago() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Detalle del cobro ──
          _buildTarjetaDetalle(),
          const SizedBox(height: 20),

          // ── Método de pago ──
          const Text('Método de pago',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            _chipMetodo('💵', 'efectivo', 'Efectivo'),
            const SizedBox(width: 10),
            _chipMetodo('📱', 'qr', 'QR'),
            const SizedBox(width: 10),
            _chipMetodo('🏦', 'transferencia', 'Transfer.'),
          ]),
          const SizedBox(height: 20),

          // ── QR si el método es qr ──
          if (_metodoPago == 'qr' && _pago!.qrImagenUrl != null) ...[
            const Text('Escanea el QR para pagar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _mostrarQR = !_mostrarQR),
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: Colors.green.shade200, width: 2),
                ),
                child: Column(children: [
                  Image.network(
                    _pago!.qrImagenUrl!,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Column(children: [
                      Icon(Icons.qr_code, size: 80, color: Colors.grey.shade400),
                      const Text('No se pudo cargar el QR',
                          style: TextStyle(color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  const Text('Toca para ampliar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // Referencia de transferencia
            TextFormField(
              controller: _refCtrl,
              decoration: InputDecoration(
                labelText:  'Número de referencia / transacción',
                hintText:   'Ej: 123456789',
                prefixIcon: const Icon(Icons.tag),
                border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled:     true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_metodoPago == 'transferencia') ...[
            TextFormField(
              controller: _refCtrl,
              decoration: InputDecoration(
                labelText:  'Número de referencia / transacción',
                hintText:   'Ingresa el número de referencia',
                prefixIcon: const Icon(Icons.tag),
                border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled:     true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Subir comprobante ──
          const Text('Comprobante de pago (opcional)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _seleccionarComprobante,
            child: Container(
              width:  double.infinity,
              height: _comprobanteXFile != null ? 180 : 100,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _comprobanteXFile != null
                      ? Colors.green : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: _comprobanteXFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? Image.memory(_comprobanteBytes!, fit: BoxFit.cover, width: double.infinity)
                          : Image.file(_comprobanteFile!,   fit: BoxFit.cover, width: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 6),
                        Text('Toca para adjuntar foto del comprobante',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
            ),
          ),
          if (_comprobanteXFile != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_comprobanteXFile!.name,
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _comprobanteXFile  = null;
                  _comprobanteBytes  = null;
                  _comprobanteFile   = null;
                }),
                child: const Text('Quitar', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ]),
          ],
          const SizedBox(height: 32),

          // ── Botón confirmar ──
          SizedBox(
            width:  double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon:  _pagando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(
                _pagando ? 'Procesando...' : 'CONFIRMAR PAGO — Bs ${_pago!.montoTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _pagando ? null : _confirmarPago,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Tarjeta de detalle del cobro ──────────────────────────
  Widget _buildTarjetaDetalle() {
    final p = _pago!;
    return Card(
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50, borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long, color: Colors.green.shade700, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.tallerNombre ?? 'Taller',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (p.tecnicoNombre != null)
                    Text('Técnico: ${p.tecnicoNombre}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              )),
              // Badge estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        p.estaPagado ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: p.estaPagado ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Text(
                  p.estaPagado ? '✅ Pagado' : '⏳ Pendiente',
                  style: TextStyle(
                    fontSize:   12, fontWeight: FontWeight.bold,
                    color: p.estaPagado ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ]),
            const Divider(height: 24),

            // Descripción del servicio
            if (p.descripcion != null) ...[
              const Text('Servicio realizado',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(p.descripcion!,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const Divider(height: 20),
            ],

            // Monto
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total a pagar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text('Bs ${p.montoTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize:   24, fontWeight: FontWeight.w900,
                      color: Colors.green.shade700,
                    )),
              ],
            ),
            const SizedBox(height: 6),

            // Método sugerido por el técnico
            Row(children: [
              const Text('Método sugerido: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(p.metodo.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ]),

            // Comprobante si ya pagó
            if (p.estaPagado && p.comprobanteUrl != null) ...[
              const Divider(height: 20),
              const Text('Comprobante adjunto',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'http://185.214.134.23:8000/${p.comprobanteUrl}',
                  height: 150, fit: BoxFit.cover, width: double.infinity,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Chip de método de pago ────────────────────────────────
  Widget _chipMetodo(String emoji, String valor, String label) {
    final seleccionado = _metodoPago == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodoPago = valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:        seleccionado ? Colors.green.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
              color: seleccionado ? Colors.green.shade500 : Colors.grey.shade300,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                    color:      seleccionado ? Colors.green.shade700 : Colors.grey.shade600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}