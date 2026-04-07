import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pichangaya/core/theme/app_colors.dart';
import 'package:pichangaya/shared/api/api_client.dart';
import 'package:pichangaya/core/constants/api_constants.dart';

class AdminTimersPage extends StatefulWidget {
  const AdminTimersPage({super.key});
  @override
  State<AdminTimersPage> createState() => _AdminTimersPageState();
}

class _AdminTimersPageState extends State<AdminTimersPage> {
  // Reservas en curso (active)
  List<Map<String, dynamic>> _activos = [];
  // Reservas confirmadas esperando hora (confirmed)
  List<Map<String, dynamic>> _enEspera = [];
  Timer? _tick;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Tick cada segundo para actualizar countdowns
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Cargar activos y confirmados en paralelo
      final resActivos = await ApiClient().dio.get(
          ApiConstants.adminReservas,
          queryParameters: {'estado': 'active'});
      final resConfirmados = await ApiClient().dio.get(
          ApiConstants.adminReservas,
          queryParameters: {'estado': 'confirmed'});

      setState(() {
        _activos = _parsear(resActivos.data as List);
        _enEspera = _parsear(resConfirmados.data as List);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> _parsear(List data) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // Tiempo restante hasta hora de inicio (para en espera)
  String _tiempoHastaInicio(Map<String, dynamic> r) {
    try {
      final fecha  = r['fecha'] as String;
      final inicio = r['hora_inicio'] as String;
      final partes = inicio.split(':');
      final dt = DateTime(
        int.parse(fecha.split('-')[0]),
        int.parse(fecha.split('-')[1]),
        int.parse(fecha.split('-')[2]),
        int.parse(partes[0]),
        int.parse(partes[1]),
      );
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return 'Ya puede jugar';
      final h   = diff.inHours;
      final min = (diff.inMinutes % 60).toString().padLeft(2, '0');
      if (h > 0) return 'En ${h}h ${min}m';
      return 'En ${diff.inMinutes}m';
    } catch (_) { return '—'; }
  }

  // Countdown restante del partido (para activos)
  String _countdown(Map<String, dynamic> r) {
    try {
      final fecha = r['fecha'] as String;
      final fin   = r['hora_fin'] as String;
      final p     = fin.split(':');
      final dt    = DateTime(
        int.parse(fecha.split('-')[0]),
        int.parse(fecha.split('-')[1]),
        int.parse(fecha.split('-')[2]),
        int.parse(p[0]), int.parse(p[1]),
      );
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return '00:00';
      final min = (diff.inMinutes).toString().padLeft(2, '0');
      final seg = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$min:$seg';
    } catch (_) { return '00:00'; }
  }

  Color _colorCountdown(Map<String, dynamic> r) {
    try {
      final fecha = r['fecha'] as String;
      final fin   = r['hora_fin'] as String;
      final p     = fin.split(':');
      final dt    = DateTime(
        int.parse(fecha.split('-')[0]),
        int.parse(fecha.split('-')[1]),
        int.parse(fecha.split('-')[2]),
        int.parse(p[0]), int.parse(p[1]),
      );
      final diff = dt.difference(DateTime.now()).inSeconds;
      if (diff <= 0)         return AppColors.rojo;
      if (diff < 5 * 60)     return AppColors.rojo;
      if (diff < 15 * 60)    return AppColors.amarillo;
      return AppColors.verde;
    } catch (_) { return AppColors.verde; }
  }

  double _progreso(Map<String, dynamic> r) {
    try {
      final fecha  = r['fecha'] as String;
      final ini    = r['hora_inicio'] as String;
      final fin    = r['hora_fin'] as String;
      final pi     = ini.split(':');
      final pf     = fin.split(':');
      final y = int.parse(fecha.split('-')[0]);
      final m = int.parse(fecha.split('-')[1]);
      final d = int.parse(fecha.split('-')[2]);
      final dtIni  = DateTime(y, m, d, int.parse(pi[0]), int.parse(pi[1]));
      final dtFin  = DateTime(y, m, d, int.parse(pf[0]), int.parse(pf[1]));
      final total  = dtFin.difference(dtIni).inSeconds;
      final pasado = DateTime.now().difference(dtIni).inSeconds;
      return (pasado / total).clamp(0.0, 1.0);
    } catch (_) { return 0.5; }
  }

  Future<void> _iniciarPartido(Map<String, dynamic> r) async {
    try {
      await ApiClient().dio.patch(
        '/admin/reservas/${r['id']}/estado',
        data: {'estado': 'active'},
      );
      _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('▶️ Partido iniciado'),
        backgroundColor: AppColors.verde,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error al iniciar partido'),
        backgroundColor: AppColors.rojo,
      ));
    }
  }

  Future<void> _finalizarPartido(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.negro2,
        title: const Text('¿Finalizar partido?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
            '${r['cancha_nombre'] ?? ''} · ${r['cliente_nombre'] ?? ''}',
            style: const TextStyle(color: AppColors.texto2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.texto2))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: AppColors.negro),
              child: const Text('🏁 Finalizar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient().dio.patch(
        '/admin/reservas/${r['id']}/estado',
        data: {'estado': 'done'},
      );
      _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🏁 Partido finalizado'),
        backgroundColor: AppColors.azul,
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: AppColors.rojo)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.verde,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ══════════════════════════════════════
          // SECCIÓN 1 — PARTIDOS EN CURSO
          // ══════════════════════════════════════
          _seccionHeader('⏱️ PARTIDOS EN CURSO',
              '${_activos.length} activos', AppColors.verde),
          const SizedBox(height: 10),

          if (_activos.isEmpty)
            _emptyCard('Sin partidos activos.')
          else
            ..._activos.map((r) => _cardActivo(r)).toList(),

          const SizedBox(height: 24),

          // ══════════════════════════════════════
          // SECCIÓN 2 — RESERVAS CONFIRMADAS (ESPERANDO)
          // ══════════════════════════════════════
          _seccionHeader('✅ INICIAR PARTIDO',
              '${_enEspera.length} confirmadas', AppColors.azul),
          const SizedBox(height: 10),

          if (_enEspera.isEmpty)
            _emptyCard('Sin reservas confirmadas pendientes.')
          else
            _tablaEspera(),

        ]),
      ),
    );
  }

  // ── Card partido activo con countdown ──────────────────────
  Widget _cardActivo(Map<String, dynamic> r) {
    final cd    = _countdown(r);
    final color = _colorCountdown(r);
    final prog  = _progreso(r);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['cancha_nombre']?.toString() ?? '—',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text(r['local_nombre']?.toString() ?? '—',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.texto2)),
              const SizedBox(height: 4),
              Text('👤 ${r['cliente_nombre']?.toString() ?? '—'}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.texto2)),
              Text('🕐 ${r['hora_inicio'] ?? ''} – ${r['hora_fin'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.texto2)),
            ])),

            // Countdown
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(cd,
                  style: TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w900,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              Text('restante',
                  style: TextStyle(fontSize: 10, color: color)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _finalizarPartido(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.azul.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.azul)),
                  child: const Text('🏁 Finalizar',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.azul)),
                ),
              ),
            ]),
          ]),
        ),

        // Barra de progreso
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: prog,
                backgroundColor: AppColors.negro3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 3),
            Row(children: [
              Text(r['hora_inicio'] ?? '',
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.texto2)),
              const Spacer(),
              Text('${(prog * 100).toInt()}% jugado',
                  style: TextStyle(fontSize: 9, color: color)),
              const Spacer(),
              Text(r['hora_fin'] ?? '',
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.texto2)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Tabla de reservas confirmadas en espera ─────────────────
  Widget _tablaEspera() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde)),
      child: Column(children: [
        // Header tabla
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.negro3,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          child: const Row(children: [
            Expanded(flex: 3, child: Text('CLIENTE',
                style: TextStyle(fontSize: 10, color: AppColors.texto2,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text('CANCHA',
                style: TextStyle(fontSize: 10, color: AppColors.texto2,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text('HORA',
                style: TextStyle(fontSize: 10, color: AppColors.texto2,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5))),
            SizedBox(width: 70, child: Text('ACCIÓN',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.texto2,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5))),
          ]),
        ),

        // Filas
        ..._enEspera.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final espera = _tiempoHastaInicio(r);
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: i < _enEspera.length - 1
                  ? const Border(
                      bottom: BorderSide(color: AppColors.borde))
                  : null),
            child: Row(children: [
              Expanded(flex: 3, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['cliente_nombre']?.toString() ?? '—',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text(espera,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.amarillo)),
              ])),
              Expanded(flex: 2, child: Text(
                  r['cancha_nombre']?.toString() ?? '—',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.texto2))),
              Expanded(flex: 2, child: Text(
                  r['hora_inicio']?.toString() ?? '—',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white))),
              SizedBox(
                width: 70,
                child: Center(child: GestureDetector(
                  onTap: () => _iniciarPartido(r),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.verde,
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.play_arrow,
                        color: AppColors.negro, size: 22),
                  ),
                )),
              ),
            ]),
          );
        }).toList(),
      ]),
    );
  }

  Widget _seccionHeader(String titulo, String sub, Color color) =>
      Row(children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(titulo, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: color, letterSpacing: 0.5)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
          child: Text(sub,
              style: TextStyle(fontSize: 11, color: color,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        GestureDetector(onTap: _cargar,
            child: const Icon(Icons.refresh,
                color: AppColors.texto2, size: 16)),
      ]);

  Widget _emptyCard(String msg) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.negro2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borde)),
      child: Center(child: Text(msg,
          style: const TextStyle(color: AppColors.texto2, fontSize: 13))));
}
