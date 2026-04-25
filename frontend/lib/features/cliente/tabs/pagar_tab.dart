import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/shared/models/pago_model.dart';
import 'dart:typed_data';

class PagarTab extends StatefulWidget {
  const PagarTab({super.key});
  @override
  State<PagarTab> createState() => _PagarTabState();
}

class _PagarTabState extends State<PagarTab> {
  List<PagoModel> _pagos = [];
  bool _loading = true;
  String? _error;
  PagoModel? _pagoSeleccionado;
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  bool _subiendo = false;
  String? _exito;
  String? _errorSubida;

  int _page = 0;
  static const double _overhead   = 210.0; // appbar + bottomnav + header + paginacion
  static const double _cardHeight = 110.0; // card colapsado + margen

  int _pageSize(BuildContext ctx) {
    final available = MediaQuery.of(ctx).size.height - _overhead;
    return (available / _cardHeight).floor().clamp(2, 20);
  }

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get('/pagos/mis-pagos');
      setState(() {
        _pagos = (res.data as List).map((j) => PagoModel.fromJson(j)).toList();
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar pagos'; _loading = false; });
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagenBytes = bytes;
      _imagenNombre = picked.name;
      _exito = null;
      _errorSubida = null;
    });
  }

  Future<void> _subirVoucher() async {
    if (_pagoSeleccionado == null || _imagenBytes == null) return;
    setState(() { _subiendo = true; _errorSubida = null; _exito = null; });
    try {
      final formData = FormData.fromMap({
        'imagen': MultipartFile.fromBytes(_imagenBytes!,
            filename: _imagenNombre ?? 'voucher.jpg',
            contentType: DioMediaType('image', 'jpeg')),
      });
      await ApiClient().dio.post('/pagos/${_pagoSeleccionado!.id}/voucher',
          data: formData, options: Options(contentType: 'multipart/form-data'));
      setState(() {
        _exito = '✅ Voucher enviado. El admin verificará tu pago pronto.';
        _imagenBytes = null;
        _imagenNombre = null;
        _subiendo = false;
        _pagoSeleccionado = null;
      });
      _cargarPagos();
    } catch (e) {
      setState(() { _errorSubida = 'Error al subir el voucher.'; _subiendo = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null)
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargarPagos, child: const Text('Reintentar')),
      ]));

    final ps    = _pageSize(context);
    final total = (_pagos.length / ps).ceil();
    final page  = _page.clamp(0, total > 0 ? total - 1 : 0);
    final items = _pagos.skip(page * ps).take(ps).toList();

    return Column(children: [
      // ── Header ─────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
        child: Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('💳 Mis Pagos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            SizedBox(height: 2),
            Text('Toca un pago para subir tu voucher',
                style: TextStyle(fontSize: 12, color: AppColors.texto2)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: _cargarPagos,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.refresh, color: AppColors.texto2, size: 20),
            ),
          ),
        ]),
      ),

      // ── Mensaje de éxito ────────────────────────────────────────
      if (_exito != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.verde.withOpacity(0.4)),
            ),
            child: Text(_exito!, style: const TextStyle(color: AppColors.verde, fontSize: 13)),
          ),
        ),

      // ── Lista paginada ──────────────────────────────────────────
      if (_pagos.isEmpty)
        const Expanded(child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('💳', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No tienes pagos registrados',
                style: TextStyle(color: AppColors.texto2, fontSize: 15)),
            SizedBox(height: 4),
            Text('Reserva una cancha para ver tus pagos aquí',
                style: TextStyle(color: AppColors.texto2, fontSize: 12)),
          ]),
        ))
      else
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarPagos,
            color: AppColors.verde,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              itemCount: items.length,
              itemBuilder: (_, i) => _cardPago(items[i]),
            ),
          ),
        ),

      // ── Paginación ──────────────────────────────────────────────
      if (total > 1) ...[
        _paginacion(total, page),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Widget _cardPago(PagoModel pago) {
    final sel = _pagoSeleccionado?.id == pago.id;
    return GestureDetector(
      onTap: () => setState(() {
        _pagoSeleccionado = sel ? null : pago;
        _imagenBytes = null;
        _exito = null;
        _errorSubida = null;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.verde.withOpacity(0.05) : AppColors.negro2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.verde : AppColors.borde,
              width: sel ? 1.5 : 1),
        ),
        child: Column(children: [
          // Fila principal
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: _colorMetodo(pago.metodo).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                    child: Text(_iconoMetodo(pago.metodo),
                        style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pago.metodo.toUpperCase(),
                    style: TextStyle(
                        fontSize: 13,
                        color: _colorMetodo(pago.metodo),
                        fontWeight: FontWeight.w700)),
                if (pago.reservaCodigo != null)
                  Text('Reserva ${pago.reservaCodigo}',
                      style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
                Text(pago.fecha,
                    style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
                Row(children: [
                  Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pago.voucherUrl != null
                              ? AppColors.verde
                              : AppColors.amarillo)),
                  const SizedBox(width: 4),
                  Text(
                      pago.voucherUrl != null ? 'Voucher enviado' : 'Sin voucher',
                      style: TextStyle(
                          fontSize: 10,
                          color: pago.voucherUrl != null
                              ? AppColors.verde
                              : AppColors.amarillo)),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('S/.${pago.monto.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.verde)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _colorEstado(pago.estado).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(pago.estado.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9,
                          color: _colorEstado(pago.estado),
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),

          // ── Sección expandida al tocar el card ──────────────────
          if (sel) ...[
            const Divider(color: AppColors.borde, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Aviso si fue rechazado
                if (pago.estado == 'rechazado') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.rojo.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.rojo.withOpacity(0.35)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.rojo, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Tu pago fue rechazado. Sube un nuevo voucher o contacta al local.',
                        style: TextStyle(color: AppColors.rojo, fontSize: 12),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],

                // Ver voucher ya enviado (solo lectura si está verificado)
                if (pago.voucherUrl != null && pago.estado == 'verificado') ...[
                  const Text('VOUCHER VERIFICADO',
                      style: TextStyle(fontSize: 10, color: AppColors.verde,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      pago.voucherUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(height: 140,
                              color: AppColors.negro3,
                              child: const Center(child: CircularProgressIndicator(
                                  color: AppColors.verde, strokeWidth: 2))),
                      errorBuilder: (_, __, ___) => Container(
                          height: 60, color: AppColors.negro3,
                          child: const Center(child: Text('No se pudo cargar la imagen',
                              style: TextStyle(color: AppColors.texto2, fontSize: 12)))),
                    ),
                  ),
                ],

                // Uploader: si no está verificado (pendiente sin voucher, pendiente con voucher, o rechazado)
                if (pago.estado != 'verificado') ...[
                  if (pago.voucherUrl != null) ...[
                    const Text('VOUCHER ACTUAL',
                        style: TextStyle(fontSize: 10, color: AppColors.texto2,
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        pago.voucherUrl!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('REEMPLAZAR VOUCHER',
                        style: TextStyle(fontSize: 10, color: AppColors.amarillo,
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                  ] else ...[
                    const Text('SUBIR VOUCHER',
                        style: TextStyle(fontSize: 10, color: AppColors.texto2,
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                  ],

                  GestureDetector(
                    onTap: _seleccionarImagen,
                    child: Container(
                      height: _imagenBytes != null ? 120 : 80,
                      decoration: BoxDecoration(
                          color: AppColors.negro3,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _imagenBytes != null ? AppColors.verde : AppColors.borde)),
                      child: _imagenBytes != null
                          ? Stack(children: [
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(_imagenBytes!,
                                      width: double.infinity, fit: BoxFit.cover)),
                              Positioned(
                                  top: 6, right: 6,
                                  child: GestureDetector(
                                      onTap: () => setState(() => _imagenBytes = null),
                                      child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                              color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, color: Colors.white, size: 14)))),
                            ])
                          : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.upload_file, color: AppColors.verde, size: 26),
                              SizedBox(height: 4),
                              Text('Toca para seleccionar imagen',
                                  style: TextStyle(color: AppColors.texto2, fontSize: 12)),
                            ])),
                    ),
                  ),

                  if (_errorSubida != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorSubida!, style: const TextStyle(color: AppColors.rojo, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                        onPressed: _seleccionarImagen,
                        child: const Text('📷 Elegir'))),
                    const SizedBox(width: 8),
                    Expanded(child: ElevatedButton(
                        onPressed: (_imagenBytes != null && !_subiendo) ? _subirVoucher : null,
                        child: _subiendo
                            ? const SizedBox(height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                            : const Text('✅ Enviar'))),
                  ]),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _paginacion(int total, int current) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _arrowBtn(Icons.arrow_back_ios_new, current > 0,
          () => setState(() { _page = current - 1; _pagoSeleccionado = null; })),
      ...List.generate(total > 9 ? 0 : total, (i) => _pageNum(i, current)),
      if (total > 9) Text('${current + 1} / $total',
          style: const TextStyle(color: AppColors.verde, fontSize: 14, fontWeight: FontWeight.w700)),
      _arrowBtn(Icons.arrow_forward_ios, current < total - 1,
          () => setState(() { _page = current + 1; _pagoSeleccionado = null; })),
    ]),
  );

  Widget _pageNum(int i, int current) => GestureDetector(
    onTap: () => setState(() { _page = i; _pagoSeleccionado = null; }),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: i == current ? AppColors.verde.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: i == current ? AppColors.verde : Colors.transparent),
      ),
      child: Text('${i + 1}', style: TextStyle(
        fontSize: 13,
        fontWeight: i == current ? FontWeight.w700 : FontWeight.normal,
        color: i == current ? AppColors.verde : AppColors.texto2,
      )),
    ),
  );

  Widget _arrowBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Icon(icon, size: 16, color: enabled ? AppColors.verde : AppColors.borde),
    ),
  );

  Color _colorMetodo(String m) {
    switch (m) {
      case 'yape': return const Color(0xFF7B2FBE);
      case 'plin': return AppColors.azul;
      case 'transferencia': return AppColors.verde;
      default: return AppColors.texto2;
    }
  }

  String _iconoMetodo(String m) {
    switch (m) {
      case 'yape': return '📱';
      case 'plin': return '💙';
      case 'transferencia': return '🏦';
      case 'efectivo': return '💵';
      default: return '💳';
    }
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'verificado': return AppColors.verde;
      case 'pendiente': return AppColors.amarillo;
      case 'rechazado': return AppColors.rojo;
      default: return AppColors.texto2;
    }
  }
}
