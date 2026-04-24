import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
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
  final TextEditingController _busquedaCtrl = TextEditingController();

  LatLng? _userPos;
  bool _gpsActivo = false;
  double _radio = 5.0;
  List<LocalModel> _locales = [];
  bool _loading = true;
  bool _buscando = false;
  bool _modoTodas = false;
  String? _error;
  LocalModel? _localPopup;

  static const _defaultPos = LatLng(-11.9435, -77.0606);

  @override
  void initState() {
    super.initState();
    _iniciarGPS();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  // ── GPS ────────────────────────────────────────────────────────
  Future<void> _iniciarGPS() async {
    setState(() { _loading = true; _error = null; _modoTodas = false; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() { _userPos = _defaultPos; _gpsActivo = false; });
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
      setState(() { _userPos = _defaultPos; _gpsActivo = false; });
    }
    await _cargarLocales();
  }

  // ── Carga con radio (cerca) ────────────────────────────────────
  Future<void> _cargarLocales() async {
    if (_modoTodas) { await _cargarTodosLocales(); return; }
    if (_userPos == null) return;
    setState(() { _loading = true; _error = null; });
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
        _locales = (res.data as List).map((j) => LocalModel.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar locales.'; _loading = false; });
    }
  }

  // ── Carga TODAS (sin filtro de radio) ─────────────────────────
  Future<void> _cargarTodosLocales() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get(ApiConstants.locales);
      final lista = (res.data as List).map((j) => LocalModel.fromJson(j)).toList();
      setState(() { _locales = lista; _loading = false; });

      // Si hay locales, ajustar el mapa para mostrarlos todos
      if (lista.isNotEmpty) {
        final lats = lista.map((l) => l.lat).toList();
        final lngs = lista.map((l) => l.lng).toList();
        final centerLat = (lats.reduce(min) + lats.reduce(max)) / 2;
        final centerLng = (lngs.reduce(min) + lngs.reduce(max)) / 2;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(LatLng(centerLat, centerLng), 11.0);
        });
      }
    } catch (e) {
      setState(() { _error = 'Error al cargar locales.'; _loading = false; });
    }
  }

  // ── Geocoding por zona (Nominatim / OpenStreetMap) ─────────────
  Future<void> _buscarZona(String zona) async {
    final q = zona.trim();
    if (q.isEmpty) return;
    setState(() { _buscando = true; _modoTodas = false; });
    try {
      final geo = Dio();
      final res = await geo.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': '$q, Lima, Peru', 'format': 'json', 'limit': 1},
        options: Options(
          headers: {'User-Agent': 'PichangaYa/1.0 (reservas@pichangaya.pe)'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final results = res.data as List;
      if (results.isNotEmpty) {
        final lat = double.parse(results[0]['lat'] as String);
        final lng = double.parse(results[0]['lon'] as String);
        setState(() { _userPos = LatLng(lat, lng); });
        _mapController.move(_userPos!, 13.5);
        await _cargarLocales();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No encontré "$q". Prueba con otro nombre de distrito.'),
            backgroundColor: Colors.orange.shade800,
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al buscar zona. Verifica tu conexión.'),
          backgroundColor: AppColors.rojo,
        ));
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _mostrarPopup(LocalModel local) {
    setState(() => _localPopup = local);
    final punto = LatLng(local.lat - 0.003, local.lng);
    _mapController.move(punto, 15.0);
  }

  void _cerrarPopup() => setState(() => _localPopup = null);

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildHeader(),
      Expanded(
        flex: 55,
        child: Stack(children: [
          _buildMapa(),
          Positioned(top: 10, left: 10, child: _buildZoomControls()),
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: AppColors.verde)),
            ),
        ]),
      ),
      Expanded(flex: 45, child: _buildListaCercanos()),
    ]);
  }

  // ── HEADER con buscador ────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      child: Column(children: [
        // Fila 1: radio + GPS + refresh
        Row(children: [
          const Text('Radio:',
              style: TextStyle(fontSize: 11, color: AppColors.texto2)),
          const SizedBox(width: 6),
          ...[0.5, 1.0, 2.0, 5.0].map((r) => GestureDetector(
            onTap: () {
              setState(() { _radio = r; _modoTodas = false; });
              _cargarLocales();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 5),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (!_modoTodas && _radio == r)
                    ? AppColors.verde.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (!_modoTodas && _radio == r) ? AppColors.verde : AppColors.borde,
                ),
              ),
              child: Text(
                r < 1 ? '${(r * 1000).toInt()}m' : '${r.toInt()}km',
                style: TextStyle(
                  fontSize: 11,
                  color: (!_modoTodas && _radio == r) ? AppColors.verde : AppColors.texto2,
                  fontWeight: (!_modoTodas && _radio == r) ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          )),
          const Spacer(),
          // Badge GPS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
              Text(_gpsActivo ? 'GPS' : 'Manual',
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
        const SizedBox(height: 8),
        // Fila 2: buscador por zona
        Row(children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.negro3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: Row(children: [
                const SizedBox(width: 10),
                const Icon(Icons.search, color: AppColors.texto2, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _busquedaCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Buscar zona... (ej: Comas, Surco)',
                      hintStyle: TextStyle(color: AppColors.texto2, fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: _buscarZona,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                if (_buscando)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        color: AppColors.verde, strokeWidth: 2),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _buscarZona(_busquedaCtrl.text),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.verde,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.search, color: Colors.black, size: 16),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Botón "Ver todas"
          GestureDetector(
            onTap: () {
              setState(() { _modoTodas = true; _busquedaCtrl.clear(); });
              _cargarTodosLocales();
            },
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _modoTodas
                    ? AppColors.verde.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _modoTodas ? AppColors.verde : AppColors.borde,
                ),
              ),
              child: Row(children: [
                Icon(Icons.public,
                    size: 14,
                    color: _modoTodas ? AppColors.verde : AppColors.texto2),
                const SizedBox(width: 4),
                Text('Todas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _modoTodas ? AppColors.verde : AppColors.texto2,
                    )),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── MAPA ──────────────────────────────────────────────────────
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
        if (_userPos != null && !_modoTodas)
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
          // Posición del usuario
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
                  boxShadow: [BoxShadow(
                    color: AppColors.azul.withOpacity(0.5), blurRadius: 6)],
                ),
              ),
            ),
          // Marcadores de locales — pelota 3D animada
          ..._locales.map((local) {
            final sel = _localPopup?.id == local.id;
            final markerH = sel ? 240.0 : 80.0;
            final markerW = sel ? 200.0 : 52.0;
            return Marker(
              point: LatLng(local.lat, local.lng),
              width: markerW,
              height: markerH,
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () => sel ? _cerrarPopup() : _mostrarPopup(local),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sel) ...[
                      _buildPopupBurbuja(local),
                      const SizedBox(height: 4),
                    ],
                    // Pelota 3D animada con pin
                    _SoccerPinMarker(selected: sel),
                  ],
                ),
              ),
            );
          }).toList(),
        ]),
      ],
    );
  }

  // ── POPUP ─────────────────────────────────────────────────────
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
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sports_soccer, color: AppColors.verde, size: 13),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                local.nombre.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.3,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _cerrarPopup,
              child: const Icon(Icons.close, color: AppColors.texto2, size: 13),
            ),
          ]),
          const SizedBox(height: 3),
          Text(local.direccion,
              style: const TextStyle(fontSize: 9, color: AppColors.texto2),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            Text('🏟 ${local.numCanchas ?? 0} canchas',
                style: const TextStyle(fontSize: 9, color: AppColors.texto2)),
            if (local.distanciaKm != null) ...[
              const Text(' · ', style: TextStyle(color: AppColors.texto2, fontSize: 9)),
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
                fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.verde,
              ),
            ),
          ],
          const SizedBox(height: 8),
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
                        fontSize: 10, fontWeight: FontWeight.w800,
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
    _zoomBtn(Icons.add,
        () => _mapController.move(_mapController.camera.center,
            _mapController.camera.zoom + 1)),
    Container(width: 32, height: 1, color: Colors.black12),
    _zoomBtn(Icons.remove,
        () => _mapController.move(_mapController.camera.center,
            _mapController.camera.zoom - 1)),
  ]);

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(icon, color: Colors.black87, size: 18),
    ),
  );

  // ── LISTA ─────────────────────────────────────────────────────
  Widget _buildListaCercanos() {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));

    return Column(children: [
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
          Icon(
            _modoTodas ? Icons.public : Icons.near_me,
            size: 12, color: AppColors.texto2,
          ),
          const SizedBox(width: 6),
          Text(
            _modoTodas ? '⚽ TODAS LAS CANCHAS' : '🏟️ LOCALES CERCA',
            style: const TextStyle(
              fontSize: 11, color: AppColors.texto2,
              fontWeight: FontWeight.w700, letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text('${_locales.length} locales',
              style: const TextStyle(fontSize: 11, color: AppColors.texto2)),
        ]),
      ),

      if (_locales.isEmpty)
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚽',
                    style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  _modoTodas
                      ? 'No hay canchas registradas aún.'
                      : 'No hay locales en este radio.\nPrueba aumentando la distancia\no busca por zona.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.texto2, fontSize: 12),
                ),
              ],
            ),
          ),
        )
      else
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 8,
              mainAxisSpacing: 8, childAspectRatio: 2.1,
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
                    color: sel ? AppColors.verde.withOpacity(0.08) : AppColors.negro2,
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
                      Text(
                        local.nombre.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: sel ? AppColors.verde : Colors.white,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      Text(local.direccion,
                          style: const TextStyle(fontSize: 9, color: AppColors.texto2),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(children: [
                        const Icon(Icons.stadium, color: AppColors.texto2, size: 10),
                        const SizedBox(width: 3),
                        Text('${local.numCanchas ?? 0} canchas',
                            style: const TextStyle(fontSize: 9, color: AppColors.texto2)),
                      ]),
                      Row(children: [
                        if (local.precioDesde != null)
                          Expanded(
                            child: Text(
                              'Desde S/.${local.precioDesde!.toStringAsFixed(0)} / hora',
                              style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: AppColors.verde,
                              ),
                            ),
                          ),
                        if (local.distanciaKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.verde.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              local.distanciaKm! < 1
                                  ? '${(local.distanciaKm! * 1000).toInt()}M'
                                  : '${local.distanciaKm!.toStringAsFixed(1)}KM',
                              style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w800,
                                color: AppColors.verde,
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

      // Botón ver todas (si no está en modo todas)
      if (!_modoTodas)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borde)),
          ),
          child: GestureDetector(
            onTap: () {
              setState(() { _modoTodas = true; _busquedaCtrl.clear(); });
              _cargarTodosLocales();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.verde.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public, size: 14, color: AppColors.verde),
                  SizedBox(width: 6),
                  Text(
                    'VER TODAS LAS CANCHAS EN EL MAPA',
                    style: TextStyle(
                      fontSize: 11, color: AppColors.verde,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// PELOTA 3D ANIMADA — pin estilo Google Maps
// ══════════════════════════════════════════════════════════════════

class _SoccerPinMarker extends StatefulWidget {
  final bool selected;
  const _SoccerPinMarker({required this.selected});
  @override
  State<_SoccerPinMarker> createState() => _SoccerPinMarkerState();
}

class _SoccerPinMarkerState extends State<_SoccerPinMarker>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_spinCtrl, _floatCtrl]),
      builder: (_, __) {
        // Flotación suave con curva sinusoidal
        final floatY = sin(_floatCtrl.value * pi) * 5.0;
        final shadowScale = 1.0 - (floatY / 14.0); // sombra se achica cuando sube

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pelota flotando ──────────────────────────────
            Transform.translate(
              offset: Offset(0, -floatY),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Gradiente radial que da sensación 3D (luz desde arriba-izquierda)
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    radius: 0.85,
                    colors: widget.selected
                        ? [Colors.white, AppColors.verde]
                        : [const Color(0xFFf5f5f5), const Color(0xFF1a1a1a)],
                    stops: const [0.0, 1.0],
                  ),
                  boxShadow: [
                    // Halo verde (más intenso si está seleccionado)
                    BoxShadow(
                      color: AppColors.verde.withOpacity(widget.selected ? 0.85 : 0.45),
                      blurRadius: widget.selected ? 18 : 10,
                      spreadRadius: widget.selected ? 2 : 0,
                    ),
                    // Sombra dura de profundidad
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 5,
                      offset: Offset(2, 2 + floatY * 0.3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Transform.rotate(
                    angle: _spinCtrl.value * 2 * pi,
                    child: Image.asset(
                      'assets/images/pelota.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // ── Sombra en el suelo (elipse dinámica) ─────────
            Transform.scale(
              scaleX: shadowScale.clamp(0.4, 1.0),
              scaleY: shadowScale.clamp(0.3, 0.7),
              child: Container(
                width: 22,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(
                      (0.35 * shadowScale).clamp(0.05, 0.35)),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),

            // ── Pin triangular (estilo Google Maps) ──────────
            CustomPaint(
              size: const Size(14, 9),
              painter: _PinStemPainter(
                color: widget.selected ? AppColors.verde : const Color(0xFF2e7d32),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Painter del triángulo del pin ─────────────────────────────────
class _PinStemPainter extends CustomPainter {
  final Color color;
  _PinStemPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Triángulo: base arriba, punta abajo
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Mini sombra del pin
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, paint); // redibujamos encima de la sombra
  }

  @override
  bool shouldRepaint(_PinStemPainter old) => old.color != color;
}
