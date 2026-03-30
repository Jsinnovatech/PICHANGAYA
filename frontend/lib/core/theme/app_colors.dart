import 'package:flutter/material.dart';

/// Colores extraídos 1:1 del CSS del prototipo HTML
class AppColors {
  // Primarios
  static const verde      = Color(0xFF00E676);  // --verde
  static const verdeOsc   = Color(0xFF00B04E);  // --verde-dark
  static const verdeGlow  = Color(0x2D00E676);  // --verde-glow rgba(0,230,118,0.18)

  // Fondos
  static const negro      = Color(0xFF0A0F0D);  // --negro (body)
  static const negro2     = Color(0xFF111A14);  // --negro2 (modales, sidebar)
  static const negro3     = Color(0xFF172119);  // --negro3 (inputs)
  static const card       = Color(0xFF192118);  // --card
  static const card2      = Color(0xFF1F2B22);  // --card2

  // Borde
  static const borde      = Color(0x2D00E676);  // --borde rgba(0,230,118,0.18)

  // Texto
  static const texto      = Color(0xFFE8F5E0);  // --texto
  static const texto2     = Color(0xFF8FA888);  // --texto2

  // Estados
  static const rojo       = Color(0xFFFF4444);  // --rojo
  static const amarillo   = Color(0xFFFFD600);  // --amarillo
  static const azul       = Color(0xFF29B6F6);  // --azul
  static const naranja    = Color(0xFFFF9800);  // --naranja
  static const morado     = Color(0xFFAB47BC);  // --morado

  // Badges de estado (de .badge-* del CSS)
  static const badgePendingBg  = Color(0x26FFD600);
  static const badgeActiveBg   = Color(0x2600E676);
  static const badgeDoneBg     = Color(0x268FA888);
  static const badgeCanceledBg = Color(0x26FF4444);
}
