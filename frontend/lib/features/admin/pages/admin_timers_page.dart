import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';

class AdminTimersPage extends StatefulWidget {
  const AdminTimersPage({super.key});
  @override
  State<AdminTimersPage> createState() => _State();
}

class _State extends State<AdminTimersPage> {
  List<dynamic> _reservas = [];
  bool _loading = true;
  String? _error;
  Timer? _ticker;
  final Map<String, bool> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient().dio.get('/admin/timers/hoy');
      setState(() { _reservas = res.data; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Error al cargar partidas'; _loading = false; });
    }
  }

  Future<void> _iniciar(String id) async {
    setState(() => _procesando[id] = true);
    try {
      await ApiClient().dio.patch('/admin/timers/$id/iniciar');
      await _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('▶ Partida iniciada'), backgroundColor: AppColors.verde));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _procesando.remove(id));
    }
  }

  Future<void> _finalizar(String id) async {
    setState(() => _procesando[id] = true);
    try {
      await ApiClient().dio.patch('/admin/timers/$id/finalizar');
      await _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏹ Partida finalizada'), backgroundColor: AppColors.azul));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al finalizar'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _procesando.remove(id));
    }
  }

  DateTime _horaHoy(String hora) {
    final p = hora.split(':');
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, int.parse(p[0]), int.parse(p[1]));
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '⏰ TIEMPO TERMINADO';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_error!, style: const TextStyle(color: AppColors.rojo)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
    ]));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: _reservas.isEmpty
          ? ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
              const Center(child: Column(children: [
                Text('⚽', style: TextStyle(fontSize: 56)),
                SizedBox(height: 16),
                Text('No hay partidas programadas para hoy', style: TextStyle(color: AppColors.texto2, fontSize: 14)),
                SizedBox(height: 8),
                Text('Las reservas confirmadas de hoy aparecerán aquí', style: TextStyle(color: AppColors.texto2, fontSize: 12)),
              ])),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reservas.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    const Text('Partidas de Hoy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Spacer(),
                    GestureDetector(onTap: _cargar, child: const Icon(Icons.refresh, color: AppColors.texto2, size: 18)),
                  ]),
                );
                return _cardTimer(_reservas[i - 1]);
              },
            ),
    );
  }

  Widget _cardTimer(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final estado = r['estado'] as String;
    final esActivo = estado == 'active';
    final procesando = _procesando[id] == true;

    final horaFin = _horaHoy(r['hora_fin'] as String);
    final restante = horaFin.difference(DateTime.now());
    final tiempoTerminado = restante.isNegative;

    final borderColor = esActivo
        ? (tiempoTerminado ? AppColors.rojo : AppColors.verde)
        : AppColors.amarillo.withOpacity(0.4);
    final bgColor = esActivo
        ? AppColors.verde.withOpacity(0.05)
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: esActivo ? bgColor : AppColors.negro2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: esActivo ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: esActivo ? AppColors.verde.withOpacity(0.15) : AppColors.amarillo.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(esActivo ? '🟢' : '🟡', style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['cancha_nombre'] ?? '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(r['cliente_nombre'] ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.texto2)),
            ])),
            // Badge estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (esActivo ? AppColors.verde : AppColors.amarillo).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(esActivo ? '🟢 EN JUEGO' : '⏳ CONFIRMADA',
                  style: TextStyle(fontSize: 10, color: esActivo ? AppColors.verde : AppColors.amarillo, fontWeight: FontWeight.w700)),
            ),
          ]),

          const SizedBox(height: 12),
          const Divider(color: AppColors.borde, height: 1),
          const SizedBox(height: 12),

          // Horario
          Row(children: [
            const Icon(Icons.access_time, color: AppColors.texto2, size: 14),
            const SizedBox(width: 6),
            Text('${r['hora_inicio']} — ${r['hora_fin']}',
                style: const TextStyle(fontSize: 13, color: AppColors.texto2)),
            const Spacer(),
            Text('S/.${(r['precio_total'] ?? 0.0).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.verde)),
          ]),

          // Countdown para activos
          if (esActivo) ...[
            const SizedBox(height: 14),
            Center(child: Text(
              _formatCountdown(restante),
              style: TextStyle(
                fontSize: tiempoTerminado ? 18 : 38,
                fontWeight: FontWeight.w900,
                color: tiempoTerminado ? AppColors.rojo : AppColors.verde,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )),
            if (!tiempoTerminado) Center(child: Text('tiempo restante',
                style: const TextStyle(fontSize: 11, color: AppColors.texto2))),
          ],

          const SizedBox(height: 12),

          // Botón acción
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: procesando ? null : () => esActivo ? _finalizar(id) : _iniciar(id),
              style: ElevatedButton.styleFrom(
                backgroundColor: esActivo ? AppColors.rojo : AppColors.verde,
                foregroundColor: AppColors.negro,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: procesando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negro))
                  : Text(
                      esActivo ? '⏹  FINALIZAR PARTIDA' : '▶  INICIAR PARTIDA',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
