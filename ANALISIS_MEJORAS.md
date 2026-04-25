# PichangaYa — Análisis de Bugs y Mejoras
> Generado: 2026-04-25

---

## Bugs reales encontrados

### Backend

#### 1. N+1 query en `GET /pagos/mis-pagos`
- **Archivo:** `backend/app/routers/pagos.py:53-58`
- **Problema:** Por cada pago hace un SELECT individual de la reserva. Con 50 pagos = 51 queries.
- **Fix:** Batch query igual al patrón ya usado en `mis_reservas`.
- **Estado:** PENDIENTE

#### 2. Autorización rota en endpoints admin
- **Archivo:** `backend/app/routers/admin.py:410-431` y `admin.py:434-463`
- **Problema:** `admin_eliminar_reserva` y `admin_cambiar_estado_reserva` NO verifican que la reserva pertenezca al local de ese admin. Cualquier admin puede cambiar/eliminar reservas de otro admin con solo conocer el UUID.
- **Fix:** Cruzar `reserva.cancha_id` con `admin_cancha_ids` antes de operar.
- **Estado:** PENDIENTE

#### 3. Timezone incorrecta en Timers
- **Archivo:** `backend/app/routers/admin.py:874`
- **Problema:** `datetime.now(timezone.utc).date()` — el servidor corre en UTC pero Lima es UTC-5. El tab de Timers puede mostrar el día equivocado entre las 12am y las 5am hora Lima.
- **Fix:** Usar `timezone(timedelta(hours=-5))` igual al patrón ya en el dashboard.
- **Estado:** PENDIENTE

#### 4. IMGBB_API_KEY "pendiente" guarda URL falsa en BD
- **Archivo:** `backend/app/routers/pagos.py:102-105`
- **Problema:** Si la key no está configurada, guarda `https://placeholder.com/voucher/...` en la BD. Debería lanzar error 503.
- **Fix:** Lanzar `HTTPException(503)` si la key es inválida.
- **Estado:** PENDIENTE

#### 5. N+1 en `get_disponibilidad_canchas`
- **Archivo:** `backend/app/routers/admin.py:1252-1265`
- **Problema:** Por cada cancha hace 2 queries dentro del loop (horarios + reservas). Con 5 canchas = 11 queries.
- **Fix:** Batch de horarios y reservas fuera del loop con `.in_()`.
- **Estado:** PENDIENTE

### Frontend

#### 6. Error genérico al cargar canchas
- **Archivo:** `frontend/lib/features/cliente/tabs/canchas_tab.dart:109`
- **Problema:** `catch (_)` descarta el error real. No se distingue timeout, 401, 404 o error de red.
- **Fix:** Parsear `DioException` y mostrar mensaje específico.
- **Estado:** PENDIENTE

#### 7. Datos de pago hardcodeados
- **Archivo:** `frontend/lib/features/cliente/tabs/canchas_tab.dart:1294-1299`
- **Problema:** Número Yape/Plin `993 592 328` y cuenta BCP hardcodeados en el código. Requiere deploy para cambiarlos.
- **Fix:** Traer datos de pago desde la configuración del local en el backend.
- **Estado:** PENDIENTE

#### 8. Manejo de error frágil en cancelación
- **Archivo:** `frontend/lib/features/cliente/tabs/mis_reservas_tab.dart:88-95`
- **Problema:** `e.toString().contains('400')` es frágil. Si el formato de DioException cambia, muestra error genérico.
- **Fix:** Parsear `DioException.response?.data['detail']`.
- **Estado:** PENDIENTE

---

## Mejoras por escenario

### Escenario 1 — Seguridad y datos

| # | Mejora | Impacto | Dificultad |
|---|--------|---------|------------|
| 1 | Fix autorización DELETE/PATCH reservas admin | CRÍTICO | Bajo |
| 2 | Rate limiting en `POST /auth/register` | Alto | Bajo |
| 3 | Fix timezone en timers (Lima UTC-5) | Medio | Bajo |
| 4 | Fix N+1 en `mis-pagos` | Medio | Bajo |
| 5 | Datos de pago (Yape/BCP) desde BD o config | Alto | Medio |

### Escenario 2 — Experiencia del cliente

| # | Mejora | Impacto |
|---|--------|---------|
| 1 | **Tab "Mis Pagos" real** — historial de pagos con estados y vouchers | Alto |
| 2 | **Confirmación visual post-reserva** — snackbar + animación al cerrar modal de pago | Medio |
| 3 | **Reservas recurrentes** — "reserva todos los jueves 7pm por 4 semanas" | Alto |
| 4 | **Notificación recordatorio** — push FCM automático 2h antes del partido | Alto |
| 5 | **Rating de canchas** — 1-5 estrellas al terminar una reserva (estado `done`) | Medio |
| 6 | **Disponibilidad "todo el día" dinámica** — actualmente hardcodea `08:00→00:00`; calcular desde horarios reales del local | Medio |

### Escenario 3 — Panel Admin

| # | Mejora | Impacto |
|---|--------|---------|
| 1 | **Filtro por fecha en Timers** — ahora solo muestra "hoy"; poder ver timers de otros días | Alto |
| 2 | **Búsqueda de cliente por nombre/celular** en tab Clientes | Alto |
| 3 | **Exportar a Excel/PDF** — tab Facturación con rango de fechas | Alto |
| 4 | **Gráfico de ingresos por cancha** — ahora el dashboard agrega todo | Medio |
| 5 | **Bloqueo manual de horarios** — slots bloqueados por mantenimiento/eventos privados | Alto |
| 6 | **UI precio override por hora pico** — `precio_override` ya existe en modelo pero sin UI fácil | Medio |

### Escenario 4 — Escala y rendimiento

| # | Mejora | Impacto |
|---|--------|---------|
| 1 | **Paginación server-side** — todos los endpoints devuelven listas completas; con 1000+ reservas será lento | Alto |
| 2 | **Caché de disponibilidad** — recalculada en cada request; cachear 30s con Redis o in-memory | Medio |
| 3 | **Índices en BD** — verificar `reservas(cancha_id, fecha, estado)` y `pagos(reserva_id)` tienen índices compuestos | Alto |

### Escenario 5 — Funcionalidades de negocio faltantes

| # | Mejora | Descripción |
|---|--------|------------|
| 1 | **Reembolso/devolución** | "Rechazar pago" solo cancela. No hay flujo de devolución con registro de monto devuelto |
| 2 | **Multi-local por admin** | Admin puede tener varios locales pero sin switch de local activo en dashboard |
| 3 | **Sistema de promociones** | Sin cupones, sin descuento por reserva frecuente, sin precio especial para grupos |
| 4 | **Facturación electrónica real** | Modelo `Comprobante` existe pero sin integración SUNAT/OSE real |
| 5 | **WhatsApp/SMS fallback** | Si FCM falla, no hay canal alternativo de notificación |

---

## Prioridad de ejecución

### Urgente — Bugs de seguridad y datos
- [x] Crear este documento
- [x] Fix 2: Autorización admin DELETE/PATCH sin verificar pertenencia — `admin.py`
- [x] Fix 3: Timezone timers (Lima UTC-5) — `admin.py`
- [x] Fix 1: N+1 en mis-pagos — `pagos.py`
- [x] Fix: Rate limit en `POST /auth/register` — `auth.py`
- [x] Fix 4: IMGBB placeholder URL en producción — `pagos.py`

### Siguiente sprint — UX y negocio
- [x] Datos de pago desde BD (no hardcodeados) — endpoint `GET /locales/configuracion/pagos` + frontend dinámico
- [x] Bloqueo manual de horarios — modelo `BloqueoHorario` + endpoints CRUD + UI admin + check en disponibilidad
- [x] Búsqueda de clientes por nombre/cel — ya estaba implementada client-side en `admin_clientes_page.dart`
- [x] Tab Mis Pagos funcional — ver voucher, re-subir en rechazado, aviso de rechazo, texto vacío correcto
- [x] Fix error genérico al cargar canchas — `catch(_)` → `DioException` con mensaje real
- [x] Fix manejo de error en cancelación — parsear `response.data['detail']`

### Mediano plazo
- [ ] Paginación server-side
- [ ] Exportar facturación a Excel/PDF
- [ ] Rating de canchas
- [ ] Notificación recordatorio automática (FCM)
- [ ] Reservas recurrentes
- [ ] Caché de disponibilidad
- [ ] Índices en BD

---

## Notas técnicas

### Patrón de timezone Lima (usar siempre)
```python
from datetime import timezone, timedelta
LIMA_TZ = timezone(timedelta(hours=-5))
hoy = datetime.now(LIMA_TZ).date()
```

### Patrón batch queries (sin N+1)
```python
ids = [item.id for item in lista]
rows = await db.execute(select(Model).where(Model.id.in_(ids)))
mapa = {r.id: r for r in rows.scalars().all()}
```

### Patrón verificar pertenencia admin
```python
cancha_ids_r = await db.execute(
    select(Cancha.id).join(Local).where(Local.admin_id == admin_uuid)
)
admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]
if reserva.cancha_id not in admin_cancha_ids:
    raise HTTPException(status_code=403, detail="No tienes permiso sobre esta reserva")
```

### Patrón rate limit (slowapi)
```python
@router.post("/register")
@limiter.limit("5/minute")
async def register(request: Request, data: RegisterRequest, ...):
```
