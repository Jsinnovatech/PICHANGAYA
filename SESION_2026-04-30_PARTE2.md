# PichangaYa — Sesión 2026-04-30 (Parte 2)

## Bugs corregidos y mejoras aplicadas

---

### 1. Bug crítico — Precio incorrecto en reservas (día/noche)

**Problema:**  
Los cards del rol cliente (Tab Mis Reservas y Tab Mis Pagos) y del rol admin (Tab Reservas y Tab Pagos) mostraban siempre el mismo precio para todas las reservas, sin distinguir entre horario diurno (hasta las 17:59) y nocturno (desde las 18:00). Cada cancha tiene dos tarifas configuradas: `precio_dia` y `precio_noche`, pero el backend las ignoraba.

**Causa raíz:**  
`backend/app/routers/reservas.py` línea 121 siempre usaba `cancha.precio_hora` para calcular el total, sin leer `precio_dia` ni `precio_noche`:

```python
# ❌ Antes (incorrecto)
precio_total=round(float(cancha.precio_hora) * (new_end - new_start) / 60, 2),
```

**Fix aplicado** (`backend/app/routers/reservas.py`):

```python
# ✅ Después (correcto)
# Precio según horario: día (00:00–17:59) → precio_dia, noche (18:00–23:59) → precio_noche
if hora_inicio_time.hour < 18:
    precio_por_hora = float(cancha.precio_dia or cancha.precio_hora)
else:
    precio_por_hora = float(cancha.precio_noche or cancha.precio_hora)
precio_calculado = round(precio_por_hora * (new_end - new_start) / 60, 2)
```

**Alcance del fix:**  
- Aplica automáticamente a **todos los roles** (cliente y admin) porque el precio se calcula y guarda en la BD al momento de crear la reserva, y todos los tabs leen ese mismo campo `precio_total`.
- El pago (`Pago.monto`) también queda correcto porque se copia de `nueva_reserva.precio_total`.

> ⚠️ **Nota:** Las reservas ya existentes en la BD tienen el precio viejo guardado. Solo las nuevas reservas creadas desde ahora usarán el precio correcto. Para corregir las existentes se requeriría un script SQL directo en Railway.

---

### 2. Bug — Formato de fecha incorrecto

**Problema:**  
- Tab **Mis Reservas** (cliente): fecha mostraba `30-04-2026` (con guiones)
- Tab **Mis Pagos** (cliente): fecha mostraba `2026-04-30` (formato ISO sin transformar)

**Formato deseado:** `30/04/2026` (DD/MM/YYYY con barras)

**Fix aplicado:**

`frontend/lib/features/cliente/tabs/mis_reservas_tab.dart` — función `_fmt`:
```dart
// ❌ Antes
if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
// ✅ Después
if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
```

`frontend/lib/features/cliente/tabs/pagar_tab.dart` — nueva función `_fmtFecha` + uso en el card:
```dart
String _fmtFecha(String f) {
  if (f.isEmpty) return '—';
  final dateStr = f.contains('T') ? f.split('T')[0] : f;
  final p = dateStr.split('-');
  if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
  return f;
}
// En el card: Text(_fmtFecha(pago.fecha), ...)
```

---

### 3. Mejora — Logos reales de Yape y Plin (reemplazo de emojis)

**Problema:**  
Los íconos de Yape (`📱`) y Plin (`💙`) eran emojis genéricos. Se reemplazaron por los logos oficiales de cada app como assets locales en el proyecto Flutter.

**Assets agregados:**

| Archivo | Origen |
|---|---|
| `frontend/assets/images/yape_logo.png` | `yape-app-logo-png_seeklogo-399697.png` |
| `frontend/assets/images/plin_logo.png` | `plin-logo-png_seeklogo-386806.png` |

> El `pubspec.yaml` ya tenía registrado `assets/images/` — no requirió cambios.

**Archivos modificados y tamaño del logo:**

| Archivo | Pantalla / Contexto | Tamaño |
|---|---|---|
| `features/cliente/tabs/pagar_tab.dart` | Tab Mis Pagos (cards) | 44×44 |
| `features/admin/pages/admin_pagos_page.dart` | Tab Pagos admin (cards) | 44×44 |
| `shared/modals/pago_modal.dart` | Modal de pago al reservar (ícono central grande) | 56×56 |
| `shared/modals/reserva_modal.dart` | Selector método de pago al reservar | 28×28 |
| `features/admin/pages/admin_reserva_manual_page.dart` | Selector método en reserva manual admin | 24×24 |

**Patrón usado en todos los archivos** (`_iconoWidget` / `_iconoMetodoPago` / `_buildIcono`):
```dart
if (metodo == 'yape') {
  return ClipRRect(
    borderRadius: BorderRadius.circular(N),
    child: Image.asset('assets/images/yape_logo.png', width: N, height: N, fit: BoxFit.cover),
  );
}
if (metodo == 'plin') {
  return ClipRRect(
    borderRadius: BorderRadius.circular(N),
    child: Image.asset('assets/images/plin_logo.png', width: N, height: N, fit: BoxFit.cover),
  );
}
// Otros métodos siguen usando emoji
return Text(emoji, style: TextStyle(fontSize: N));
```

**Lo que NO se cambió** (para no romper estructura):  
`super_admin_historial_pagos_page.dart` — el emoji está dentro de un `String` concatenado en un `Text`, no en un widget contenedor. Cambiarlo requeriría reestructurar el widget.

---

## Archivos modificados en esta sesión

| Archivo | Cambio |
|---|---|
| `backend/app/routers/reservas.py` | Fix precio día/noche al crear reserva |
| `frontend/lib/features/cliente/tabs/mis_reservas_tab.dart` | Formato fecha con `/` |
| `frontend/lib/features/cliente/tabs/pagar_tab.dart` | Formato fecha + logo Yape/Plin |
| `frontend/lib/features/admin/pages/admin_pagos_page.dart` | Logo Yape/Plin |
| `frontend/lib/shared/modals/pago_modal.dart` | Logo Yape/Plin en modal de pago |
| `frontend/lib/shared/modals/reserva_modal.dart` | Logo Yape/Plin en selector método |
| `frontend/lib/features/admin/pages/admin_reserva_manual_page.dart` | Logo Yape/Plin en reserva manual |
| `frontend/assets/images/yape_logo.png` | Asset nuevo |
| `frontend/assets/images/plin_logo.png` | Asset nuevo |

---

## Estado del proyecto al cierre de sesión

- Backend Railway: **desplegado y funcionando**
- Fix precio día/noche: **aplicado** — activo para nuevas reservas
- Logos Yape/Plin: **aplicados** en 5 pantallas / modals
- Formato fechas: **corregido** a DD/MM/YYYY
- APK: **pendiente de build**

---

## Reglas importantes recordadas

| Regla | Detalle |
|---|---|
| Variables Railway | Nunca poner comillas alrededor del valor |
| Precio día/noche | `hora_inicio < 18` → `precio_dia`, `>= 18` → `precio_noche`, fallback a `precio_hora` |
| Assets Flutter | Ya registrado `assets/images/` en `pubspec.yaml` — solo agregar el archivo |
| Fix de precio | Solo aplica a reservas nuevas; las existentes en BD mantienen el precio viejo |
