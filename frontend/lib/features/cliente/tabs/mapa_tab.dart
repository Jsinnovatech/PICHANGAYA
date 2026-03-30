import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/models/local_model.dart';

class MapaTab extends StatefulWidget {
  final Function(LocalModel?)? onLocalSeleccionado;
  const MapaTab({super.key, this.onLocalSeleccionado});
  @override
  State<MapaTab> createState() => _MapaTabState();
}

class _MapaTabState extends State<MapaTab> {
  final MapController _mapController = MapController();
  LatLng? _userPos;
  bool _gpsActivo = false;
  double _radio = 1.0;
  List<LocalModel> _locales = [];
  bool _loading = true;
  String? _error;
  LocalModel? _localPopup;

  static const _defaultPos = LatLng(-11.9435, -77.0606);

  @override
  void initState() {
    super.initState();
    _iniciarGPS();
  }

  Future<void> _iniciarGPS() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _userPos = _defaultPos;
          _gpsActivo = false;
        });
        await _cargarLocales();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      setState(() {
        _userPos = LatLng(pos.latitude, pos.longitude);
        _gpsActivo = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_userPos!, 14.5);
      });
    } catch (_) {
      setState(() {
        _userPos = _defaultPos;
        _gpsActivo = false;
      });
    }
    await _cargarLocales();
  }

  Future<void> _cargarLocales() async {
    if (_userPos == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(
        ApiConstants.locales,
        queryParameters: {
          'lat': _userPos!.latitude,
          'lng': _userPos!.longitude,
          'radio': _radio,
        },
      );
      setState(() {
        _locales =
            (res.data as List).map((j) => LocalModel.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar locales.';
        _loading = false;
      });
    }
  }

  void _mostrarPopup(LocalModel local) {
    setState(() {
      _localPopup = local;
    });
    // Desplazar mapa un poco hacia abajo para que el popup quede visible
    final punto = LatLng(local.lat - 0.003, local.lng);
    _mapController.move(punto, 15.0);
  }

  void _cerrarPopup() => setState(() {
        _localPopup = null;
      });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildHeader(),
      // Mapa ocupa ~55% de la pantalla
      Expanded(
        flex: 55,
        child: Stack(children: [
          _buildMapa(),
          // Zoom controls
          Positioned(top: 10, left: 10, child: _buildZoomControls()),
          // Loader
          if (_loading)
            Container(
                color: Colors.black54,
                child: const Center(
                    child: CircularProgressIndicator(color: AppColors.verde))),
        ]),
      ),
      // Lista ocupa ~45% de la pantalla
      Expanded(
        flex: 45,
        child: _buildListaCercanos(),
      ),
    ]);
  }

  // ── HEADER ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      child: Row(children: [
        // Radio selector
        const Text('Radio:',
            style: TextStyle(fontSize: 11, color: AppColors.texto2)),
        const SizedBox(width: 8),
        ...[0.5, 1.0, 2.0, 5.0]
            .map((r) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _radio = r;
                    });
                    _cargarLocales();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _radio == r
                          ? AppColors.verde.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              _radio == r ? AppColors.verde : AppColors.borde),
                    ),
                    child: Text(
                        r < 1 ? '${(r * 1000).toInt()}m' : '${r.toInt()}km',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              _radio == r ? AppColors.verde : AppColors.texto2,
                          fontWeight:
                              _radio == r ? FontWeight.w700 : FontWeight.normal,
                        )),
                  ),
                ))
            .toList(),
        const Spacer(),
        // GPS badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _gpsActivo
                ? AppColors.verde.withOpacity(0.15)
                : AppColors.texto2.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _gpsActivo ? AppColors.verde : AppColors.borde),
          ),
          child: Row(children: [
            Icon(
              _gpsActivo ? Icons.gps_fixed : Icons.gps_not_fixed,
              size: 11,
              color: _gpsActivo ? AppColors.verde : AppColors.texto2,
            ),
            const SizedBox(width: 4),
            Text(_gpsActivo ? 'GPS Activo' : 'Manual',
                style: TextStyle(
                  fontSize: 10,
                  color: _gpsActivo ? AppColors.verde : AppColors.texto2,
                )),
          ]),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _iniciarGPS,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.negro3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borde),
            ),
            child: const Icon(Icons.refresh, size: 14, color: AppColors.texto2),
          ),
        ),
      ]),
    );
  }

  // ── MAPA ─────────────────────────────────────────────────────
  Widget _buildMapa() {
    final center = _userPos ?? _defaultPos;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.5,
        minZoom: 10,
        maxZoom: 18,
        onTap: (_, __) => _cerrarPopup(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pichangaya.app',
        ),
        if (_userPos != null)
          CircleLayer(circles: [
            CircleMarker(
              point: _userPos!,
              radius: _radio * 1000,
              useRadiusInMeter: true,
              color: AppColors.verde.withOpacity(0.05),
              borderColor: AppColors.verde.withOpacity(0.25),
              borderStrokeWidth: 1.5,
            ),
          ]),
        MarkerLayer(markers: [
          // Marcador usuario
          if (_userPos != null)
            Marker(
              point: _userPos!,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.azul,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.azul.withOpacity(0.5), blurRadius: 6)
                  ],
                ),
              ),
            ),
          // Marcadores locales — con popup encima cuando se selecciona
          ..._locales.map((local) {
            final sel = _localPopup?.id == local.id;
            // Alto del marker = popup (160) + pin (40) cuando está seleccionado
            final markerH = sel ? 200.0 : 44.0;
            final markerW = sel ? 200.0 : 44.0;

            return Marker(
              point: LatLng(local.lat, local.lng),
              width: markerW,
              height: markerH,
              // Anclar en la base del pin
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () => sel ? _cerrarPopup() : _mostrarPopup(local),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Popup encima del pin ──────────────────
                    if (sel) ...[
                      _buildPopupBurbuja(local),
                      const SizedBox(height: 4),
                    ],
                    // ── Pin del marcador ──────────────────────
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : AppColors.verde,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? AppColors.verde : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.verde.withOpacity(0.5),
                            blurRadius: sel ? 14 : 6,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.sports_soccer,
                        color: sel ? AppColors.verde : Colors.black,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ]),
      ],
    );
  }

  // ── POPUP BURBUJA encima del marcador ─────────────────────────
  Widget _buildPopupBurbuja(LocalModel local) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.verde.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre + cerrar
          Row(children: [
            const Icon(Icons.sports_soccer, color: AppColors.verde, size: 13),
            const SizedBox(width: 5),
            Expanded(
                child: Text(
              local.nombre.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
            GestureDetector(
              onTap: _cerrarPopup,
              child: const Icon(Icons.close, color: AppColors.texto2, size: 13),
            ),
          ]),
          const SizedBox(height: 3),
          // Dirección
          Text(
            local.direccion,
            style: const TextStyle(fontSize: 9, color: AppColors.texto2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          // Canchas + distancia
          Row(children: [
            Text(
              '🏟 ${local.numCanchas ?? 0} canchas',
              style: const TextStyle(fontSize: 9, color: AppColors.texto2),
            ),
            if (local.distanciaKm != null) ...[
              const Text(' · ',
                  style: TextStyle(color: AppColors.texto2, fontSize: 9)),
              Text(
                local.distanciaKm! < 1
                    ? 'A ${(local.distanciaKm! * 1000).toInt()} m'
                    : 'A ${local.distanciaKm!.toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 9, color: AppColors.texto2),
              ),
            ],
          ]),
          if (local.precioDesde != null) ...[
            const SizedBox(height: 3),
            Text(
              'Desde S/.${local.precioDesde!.toStringAsFixed(0)} / hora',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.verde,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Botón
          GestureDetector(
            onTap: () {
              _cerrarPopup();
              widget.onLocalSeleccionado?.call(local);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.verde,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ver canchas del local',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      )),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.black, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ZOOM CONTROLS ─────────────────────────────────────────────
  Widget _buildZoomControls() => Column(children: [
        _zoomBtn(
            Icons.add,
            () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                )),
        Container(width: 32, height: 1, color: Colors.black12),
        _zoomBtn(
            Icons.remove,
            () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                )),
      ]);

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(icon, color: Colors.black87, size: 18),
        ),
      );

  // ── LISTA ABAJO — cards compactas mobile ──────────────────────
  Widget _buildListaCercanos() {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));

    return Column(children: [
      // Header lista
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: const BoxDecoration(
          color: AppColors.negro2,
          border: Border(
            top: BorderSide(color: AppColors.borde),
            bottom: BorderSide(color: AppColors.borde),
          ),
        ),
        child: Row(children: [
          const Text('🏟️ LOCALES CERCA',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.texto2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              )),
          const Spacer(),
          Text('${_locales.length} locales',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
        ]),
      ),

      if (_locales.isEmpty)
        const Expanded(
            child: Center(
                child: Text(
          'No hay locales en este radio.\nPrueba aumentando la distancia.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.texto2, fontSize: 12),
        )))
      else
        // Grid 2 columnas — compacto mobile
        Expanded(
            child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.1,
            // Ratio más ancho = cards más bajas y compactas
          ),
          itemCount: _locales.length,
          itemBuilder: (_, i) {
            final local = _locales[i];
            final sel = _localPopup?.id == local.id;
            return GestureDetector(
              onTap: () => _mostrarPopup(local),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.verde.withOpacity(0.08)
                      : AppColors.negro2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? AppColors.verde : AppColors.borde,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Nombre
                    Text(
                      local.nombre.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sel ? AppColors.verde : Colors.white,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Dirección
                    Text(
                      local.direccion,
                      style:
                          const TextStyle(fontSize: 9, color: AppColors.texto2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Canchas
                    Row(children: [
                      const Icon(Icons.stadium,
                          color: AppColors.texto2, size: 10),
                      const SizedBox(width: 3),
                      Text('${local.numCanchas ?? 0} canchas',
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.texto2)),
                    ]),
                    // Precio + distancia
                    Row(children: [
                      if (local.precioDesde != null)
                        Expanded(
                            child: Text(
                          'Desde S/.${local.precioDesde!.toStringAsFixed(0)} / hora',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.verde,
                          ),
                        )),
                      if (local.distanciaKm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.verde.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              local.distanciaKm! < 1
                                  ? '${(local.distanciaKm! * 1000).toInt()}M'
                                  : '${local.distanciaKm!.toStringAsFixed(1)}KM',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.verde,
                              )),
                        ),
                    ]),
                  ],
                ),
              ),
            );
          },
        )),

      // Botón buscar todas las canchas
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borde)),
        ),
        child: GestureDetector(
          onTap: () => widget.onLocalSeleccionado?.call(null),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borde),
            ),
            child: const Center(
                child: Text(
              'O BUSCA EN TODAS LAS CANCHAS',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.texto2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            )),
          ),
        ),
      ),
    ]);
  }
}
