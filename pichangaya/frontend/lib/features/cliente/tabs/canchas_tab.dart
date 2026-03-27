import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';
import 'package:pichangaya/shared/models/local_model.dart';
import 'package:pichangaya/shared/models/cancha_model.dart';

class CanchasTab extends StatefulWidget {
  final LocalModel? localFiltro;
  // Local seleccionado desde el mapa — null = mostrar todos

  const CanchasTab({super.key, this.localFiltro});

  @override
  State<CanchasTab> createState() => _CanchasTabState();
}

class _CanchasTabState extends State<CanchasTab> {
  List<CanchaModel> _canchas = [];
  bool _loading = false;
  String? _error;

  // Cancha seleccionada para ver horarios
  CanchaModel? _canchaSeleccionada;

  // Fecha seleccionada para disponibilidad
  DateTime _fechaSeleccionada = DateTime.now();

  // Horarios disponibles de la cancha seleccionada
  List<Map<String, dynamic>> _horarios = [];
  bool _loadingHorarios = false;

  // Slot seleccionado para reservar
  Map<String, dynamic>? _slotSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarCanchas();
  }

  @override
  void didUpdateWidget(CanchasTab old) {
    super.didUpdateWidget(old);
    // Si cambia el local filtro recargamos
    if (old.localFiltro?.id != widget.localFiltro?.id) {
      _canchaSeleccionada = null;
      _slotSeleccionado = null;
      _cargarCanchas();
    }
  }

  Future<void> _cargarCanchas() async {
    if (widget.localFiltro == null) {
      setState(() {
        _canchas = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(
        '${ApiConstants.locales}/${widget.localFiltro!.id}/canchas',
      );
      setState(() {
        _canchas = (res.data as List)
            .map((j) => CanchaModel.fromJson(j))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar canchas';
        _loading = false;
      });
    }
  }

  Future<void> _cargarHorarios(CanchaModel cancha, DateTime fecha) async {
    setState(() {
      _loadingHorarios = true;
      _horarios = [];
      _slotSeleccionado = null;
    });
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);
      final res = await ApiClient().dio.get(
        '${ApiConstants.locales}/${widget.localFiltro!.id}/canchas/${cancha.id}/disponibilidad',
        queryParameters: {'fecha': fechaStr},
      );
      setState(() {
        _horarios = List<Map<String, dynamic>>.from(res.data);
        _loadingHorarios = false;
      });
    } catch (e) {
      setState(() {
        _loadingHorarios = false;
      });
    }
  }

  void _seleccionarCancha(CanchaModel cancha) {
    setState(() {
      if (_canchaSeleccionada?.id == cancha.id) {
        // Toggle — si ya está seleccionada, deseleccionar
        _canchaSeleccionada = null;
        _horarios = [];
        _slotSeleccionado = null;
      } else {
        _canchaSeleccionada = cancha;
        _slotSeleccionado = null;
      }
    });
    if (_canchaSeleccionada != null) {
      _cargarHorarios(cancha, _fechaSeleccionada);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Banner del local seleccionado
            if (widget.localFiltro != null) _buildLocalBanner(),
            // Contenido principal
            Expanded(child: _buildContenido()),
          ],
        ),
        // CTA flotante cuando hay slot seleccionado
        if (_slotSeleccionado != null && _canchaSeleccionada != null)
          _buildCTAFlotante(),
      ],
    );
  }

  Widget _buildLocalBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.negro2,
        border: Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_soccer, color: AppColors.verde, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.localFiltro!.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.localFiltro!.direccion,
                  style: const TextStyle(fontSize: 11, color: AppColors.texto2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.localFiltro?.distanciaKm != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.localFiltro!.distanciaKm! < 1
                    ? '${(widget.localFiltro!.distanciaKm! * 1000).toInt()}m'
                    : '${widget.localFiltro!.distanciaKm!.toStringAsFixed(1)}km',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.verde,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (widget.localFiltro == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: AppColors.texto2, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Selecciona un local desde el mapa',
              style: TextStyle(color: AppColors.texto2, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca un marcador verde para ver sus canchas',
              style: TextStyle(color: AppColors.texto2, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verde),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.rojo)),
      );
    }

    if (_canchas.isEmpty) {
      return const Center(
        child: Text(
          'No hay canchas disponibles en este local',
          style: TextStyle(color: AppColors.texto2),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _canchas.length,
      itemBuilder: (_, i) {
        final cancha = _canchas[i];
        final seleccionada = _canchaSeleccionada?.id == cancha.id;
        return Column(
          children: [
            // Card de cancha
            _buildCanchaCard(cancha, seleccionada),
            // Horarios inline si está seleccionada
            if (seleccionada) _buildHorariosInline(cancha),
          ],
        );
      },
    );
  }

  Widget _buildCanchaCard(CanchaModel cancha, bool seleccionada) {
    return GestureDetector(
      onTap: () => _seleccionarCancha(cancha),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionada ? AppColors.negro3 : AppColors.negro2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(seleccionada ? 0 : 10),
            bottomRight: Radius.circular(seleccionada ? 0 : 10),
          ),
          border: Border.all(
            color: seleccionada ? AppColors.verde : AppColors.borde,
          ),
        ),
        child: Row(
          children: [
            // Ícono
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: AppColors.verde,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cancha.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(
                        cancha.superficie ?? 'Gras Sintético',
                        AppColors.texto2,
                      ),
                      const SizedBox(width: 6),
                      _chip('${cancha.capacidad} jugadores', AppColors.texto2),
                    ],
                  ),
                ],
              ),
            ),
            // Precio
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/.${cancha.precioHora.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.verde,
                  ),
                ),
                const Text(
                  '/hora',
                  style: TextStyle(fontSize: 10, color: AppColors.texto2),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              seleccionada
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: AppColors.texto2,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorariosInline(CanchaModel cancha) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.negro3,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border.all(color: AppColors.verde),
        // Borde verde indica que está seleccionada
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de fechas
          _buildDateTabs(),
          const SizedBox(height: 12),
          // Grid de horarios
          _buildHorariosGrid(),
        ],
      ),
    );
  }

  Widget _buildDateTabs() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        // Mostrar 7 días desde hoy
        itemBuilder: (_, i) {
          final fecha = DateTime.now().add(Duration(days: i));
          final seleccionada =
              DateFormat('yyyy-MM-dd').format(fecha) ==
              DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
          return GestureDetector(
            onTap: () {
              setState(() {
                _fechaSeleccionada = fecha;
                _slotSeleccionado = null;
              });
              _cargarHorarios(_canchaSeleccionada!, fecha);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: seleccionada
                    ? AppColors.verde.withOpacity(0.2)
                    : AppColors.negro2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: seleccionada ? AppColors.verde : AppColors.borde,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0
                        ? 'Hoy'
                        : i == 1
                        ? 'Mañ'
                        : DateFormat('EEE', 'es').format(fecha),
                    style: TextStyle(
                      fontSize: 10,
                      color: seleccionada ? AppColors.verde : AppColors.texto2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM', 'es').format(fecha),
                    style: TextStyle(
                      fontSize: 12,
                      color: seleccionada ? AppColors.verde : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorariosGrid() {
    if (_loadingHorarios) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            color: AppColors.verde,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_horarios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No hay horarios para esta fecha',
            style: TextStyle(color: AppColors.texto2, fontSize: 13),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _horarios.map((h) {
        final disponible = h['disponible'] == true;
        final horaInicio = h['hora_inicio']?.toString().substring(0, 5) ?? '';
        final seleccionado =
            _slotSeleccionado?['hora_inicio'] == h['hora_inicio'];

        return GestureDetector(
          onTap: disponible
              ? () {
                  setState(() {
                    _slotSeleccionado = seleccionado ? null : h;
                  });
                }
              : null,
          child: Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: !disponible
                  ? AppColors.negro2
                  : seleccionado
                  ? AppColors.verde
                  : AppColors.verde.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: !disponible
                    ? AppColors.borde
                    : seleccionado
                    ? AppColors.verde
                    : AppColors.verde.withOpacity(0.4),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  horaInicio,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: !disponible
                        ? AppColors.texto2
                        : seleccionado
                        ? AppColors.negro
                        : AppColors.verde,
                  ),
                ),
                if (!disponible)
                  const Text(
                    'Ocupado',
                    style: TextStyle(fontSize: 9, color: AppColors.texto2),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCTAFlotante() {
    final horaInicio =
        _slotSeleccionado?['hora_inicio']?.toString().substring(0, 5) ?? '';
    final horaFin =
        _slotSeleccionado?['hora_fin']?.toString().substring(0, 5) ?? '';
    final fechaStr = DateFormat('d MMM', 'es').format(_fechaSeleccionada);

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: GestureDetector(
        onTap: _mostrarReservaModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.verde,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.verde.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_canchaSeleccionada!.nombre} · $horaInicio - $horaFin',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.negro,
                      ),
                    ),
                    Text(
                      '$fechaStr · S/.${_canchaSeleccionada!.precioHora.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.negro.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.negro,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Reservar ➜',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.verde,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarReservaModal() async {
    if (_slotSeleccionado == null || _canchaSeleccionada == null) return;

    final horaInicio =
        _slotSeleccionado!['hora_inicio']?.toString().substring(0, 5) ?? '';
    final horaFin =
        _slotSeleccionado!['hora_fin']?.toString().substring(0, 5) ?? '';
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _ReservaModal(
        cancha: _canchaSeleccionada!,
        local: widget.localFiltro!,
        fecha: fechaStr,
        horaInicio: horaInicio,
        horaFin: horaFin,
        onReservado: () {
          setState(() {
            _slotSeleccionado = null;
          });
          _cargarHorarios(_canchaSeleccionada!, _fechaSeleccionada);
        },
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color)),
  );
}

// ══════════════════════════════════════════════
// MODAL DE RESERVA — inline para simplicidad
// ══════════════════════════════════════════════

class _ReservaModal extends StatefulWidget {
  final CanchaModel cancha;
  final LocalModel local;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final VoidCallback onReservado;

  const _ReservaModal({
    required this.cancha,
    required this.local,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.onReservado,
  });

  @override
  State<_ReservaModal> createState() => _ReservaModalState();
}

class _ReservaModalState extends State<_ReservaModal> {
  String _metodoPago = 'yape';
  String _tipoDoc = 'boleta';
  bool _loading = false;
  String? _error;
  String? _exito;

  Future<void> _reservar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient().dio.post(
        ApiConstants.reservas,
        data: {
          'cancha_id': widget.cancha.id,
          'fecha': widget.fecha,
          'hora_inicio': widget.horaInicio,
          'hora_fin': widget.horaFin,
          'metodo_pago': _metodoPago,
          'tipo_doc': _tipoDoc,
        },
      );
      setState(() {
        _exito =
            '✅ Reserva creada exitosamente. Ahora sube tu voucher de pago en el tab "Pagar".';
        _loading = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
        widget.onReservado();
      }
    } catch (e) {
      setState(() {
        _error = 'Error al crear la reserva. El horario puede estar ocupado.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borde,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Título
          const Text(
            'Confirmar Reserva',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Resumen
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.negro3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borde),
            ),
            child: Column(
              children: [
                _row('Cancha', widget.cancha.nombre),
                _row('Local', widget.local.nombre),
                _row('Fecha', widget.fecha),
                _row('Horario', '${widget.horaInicio} - ${widget.horaFin}'),
                _row(
                  'Precio',
                  'S/.${widget.cancha.precioHora.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Método de pago
          Row(
            children: [
              const Text(
                'Pago:',
                style: TextStyle(color: AppColors.texto2, fontSize: 13),
              ),
              const SizedBox(width: 8),
              ...[
                    ('yape', 'Yape'),
                    ('plin', 'Plin'),
                    ('transferencia', 'Transfer.'),
                    ('efectivo', 'Efectivo'),
                  ]
                  .map(
                    (m) => GestureDetector(
                      onTap: () => setState(() {
                        _metodoPago = m.$1;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _metodoPago == m.$1
                              ? AppColors.verde.withOpacity(0.2)
                              : AppColors.negro3,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _metodoPago == m.$1
                                ? AppColors.verde
                                : AppColors.borde,
                          ),
                        ),
                        child: Text(
                          m.$2,
                          style: TextStyle(
                            fontSize: 11,
                            color: _metodoPago == m.$1
                                ? AppColors.verde
                                : AppColors.texto2,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
          const SizedBox(height: 10),
          // Tipo documento
          Row(
            children: [
              const Text(
                'Doc:',
                style: TextStyle(color: AppColors.texto2, fontSize: 13),
              ),
              const SizedBox(width: 8),
              ...[('boleta', 'Boleta'), ('factura', 'Factura')]
                  .map(
                    (d) => GestureDetector(
                      onTap: () => setState(() {
                        _tipoDoc = d.$1;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _tipoDoc == d.$1
                              ? AppColors.verde.withOpacity(0.2)
                              : AppColors.negro3,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _tipoDoc == d.$1
                                ? AppColors.verde
                                : AppColors.borde,
                          ),
                        ),
                        child: Text(
                          d.$2,
                          style: TextStyle(
                            fontSize: 11,
                            color: _tipoDoc == d.$1
                                ? AppColors.verde
                                : AppColors.texto2,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.rojo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.rojo, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_exito != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _exito!,
                style: const TextStyle(color: AppColors.verde, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _reservar,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.negro,
                      ),
                    )
                  : const Text('✅ CONFIRMAR RESERVA'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(color: AppColors.texto2, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
