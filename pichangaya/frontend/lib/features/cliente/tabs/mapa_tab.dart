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
  // Callback para notificar al ClientShell qué local se seleccionó
  // ClientShell lo usa para cambiar al tab Canchas con ese local

  const MapaTab({super.key, this.onLocalSeleccionado});

  @override
  State<MapaTab> createState() => _MapaTabState();
}

class _MapaTabState extends State<MapaTab> {
  final MapController _mapController = MapController();

  LatLng? _userPos;
  // Posición GPS del usuario — null si no se obtuvo aún

  bool _gpsActivo = false;
  // true si el GPS está funcionando, false si usamos posición manual

  double _radio = 2.0;
  // Radio de búsqueda en km — equivale al selector del HTML

  List<LocalModel> _locales = [];
  // Locales cercanos cargados del backend

  bool _loading = true;
  String? _error;

  // Posición por defecto — Collique, Comas, Lima
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
      // Verificar permisos de ubicación
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        // Sin GPS — usar posición por defecto
        setState(() {
          _userPos = _defaultPos;
          _gpsActivo = false;
        });
        await _cargarLocales();
        return;
      }

      // Obtener posición actual
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      setState(() {
        _userPos = LatLng(pos.latitude, pos.longitude);
        _gpsActivo = true;
      });

      // Mover el mapa a la posición del usuario
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_userPos!, 14.0);
      });
    } catch (_) {
      // Si falla el GPS usar posición por defecto
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
      final lista = (res.data as List)
          .map((j) => LocalModel.fromJson(j))
          .toList();

      setState(() {
        _locales = lista;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar locales. Verifica tu conexión.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ────────────────────────────────────────────
        _buildHeader(),
        // ── Mapa ──────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              _buildMapa(),
              // Lista de locales superpuesta abajo
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildListaCercanos(),
              ),
              // Loader
              if (_loading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.verde),
                  ),
                ),
              // Error
              if (_error != null)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rojo.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      child: Column(
        children: [
          // Título + GPS badge
          Row(
            children: [
              const Text(
                '📍 Canchas Cerca de Ti',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
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
                    color: _gpsActivo ? AppColors.verde : AppColors.borde,
                  ),
                ),
                child: Text(
                  _gpsActivo ? '📡 GPS Activo' : '📍 Manual',
                  style: TextStyle(
                    fontSize: 11,
                    color: _gpsActivo ? AppColors.verde : AppColors.texto2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón refrescar
              GestureDetector(
                onTap: _iniciarGPS,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.negro3,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borde),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: AppColors.texto2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Selector de radio
          Row(
            children: [
              const Text(
                'Radio:',
                style: TextStyle(fontSize: 12, color: AppColors.texto2),
              ),
              const SizedBox(width: 8),
              ...[0.5, 1.0, 2.0, 5.0]
                  .map(
                    (r) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _radio = r;
                        });
                        _cargarLocales();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _radio == r
                              ? AppColors.verde.withOpacity(0.2)
                              : AppColors.negro3,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _radio == r
                                ? AppColors.verde
                                : AppColors.borde,
                          ),
                        ),
                        child: Text(
                          r < 1 ? '${(r * 1000).toInt()}m' : '${r.toInt()}km',
                          style: TextStyle(
                            fontSize: 11,
                            color: _radio == r
                                ? AppColors.verde
                                : AppColors.texto2,
                            fontWeight: _radio == r
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapa() {
    final center = _userPos ?? _defaultPos;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.0,
        minZoom: 10,
        maxZoom: 18,
      ),
      children: [
        // Tiles de OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pichangaya.app',
        ),

        // Círculo de radio de búsqueda
        if (_userPos != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _userPos!,
                radius: _radio * 1000,
                // radio en metros
                useRadiusInMeter: true,
                color: AppColors.verde.withOpacity(0.06),
                borderColor: AppColors.verde.withOpacity(0.3),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),

        // Marcadores de locales
        MarkerLayer(
          markers: [
            // Marcador del usuario
            if (_userPos != null)
              Marker(
                point: _userPos!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.azul,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.azul.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

            // Marcadores de locales cercanos
            ..._locales
                .map(
                  (local) => Marker(
                    point: LatLng(local.lat, local.lng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () {
                        // Al tocar un marcador → ir al tab Canchas con ese local
                        widget.onLocalSeleccionado?.call(local);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.verde,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.verde.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_soccer,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ],
    );
  }

  Widget _buildListaCercanos() {
    if (_locales.isEmpty && !_loading) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.negro2.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borde),
        ),
        child: const Text(
          'No hay canchas en este radio. Prueba aumentando la distancia.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.texto2, fontSize: 13),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.negro2.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_locales.length} canchas cerca',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.texto2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _locales.length,
              itemBuilder: (_, i) {
                final local = _locales[i];
                return GestureDetector(
                  onTap: () => widget.onLocalSeleccionado?.call(local),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.negro3,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borde),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sports_soccer,
                          color: AppColors.verde,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                local.nombre,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                local.direccion,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.texto2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Distancia
                        if (local.distanciaKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.verde.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              local.distanciaKm! < 1
                                  ? '${(local.distanciaKm! * 1000).toInt()}m'
                                  : '${local.distanciaKm!.toStringAsFixed(1)}km',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.verde,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.texto2,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
