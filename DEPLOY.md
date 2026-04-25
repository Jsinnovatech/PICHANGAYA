# PichangaYa — Guía de Despliegue a Producción

---

## PASO 1 — Backend: variables de entorno en Railway

Ir a Railway > proyecto > backend > **Variables** y verificar/actualizar:

| Variable | Valor prod |
|----------|-----------|
| `DEBUG` | `False` |
| `SECRET_KEY` | Tu clave actual (ya es válida) |
| `DATABASE_URL` | Railway lo gestiona automáticamente |
| `ALLOWED_ORIGINS` | `https://pichangaya-production-0eb7.up.railway.app` (agregar dominio web si lo tienes) |
| `IMGBB_API_KEY` | `36eaed76952b26c5c35263e22ae8597c` |
| `YAPE_NUMERO` | `993592328` |

> El `.env` local tiene `DEBUG=True` — asegúrate de que Railway tenga `DEBUG=False`.

---

## PASO 2 — Backend: crear tabla de bloqueos en Railway

Conectarse al backend de Railway y ejecutar el script una sola vez:

```bash
# Opción A: desde la terminal local con Railway CLI
railway run python crear_tabla_bloqueos.py

# Opción B: en el panel Railway > backend > Shell
python crear_tabla_bloqueos.py
```

Resultado esperado:
```
✅ Tabla bloqueos_horario creada correctamente.
```

---

## PASO 3 — Backend: hacer push del código

```bash
cd backend
git add .
git commit -m "fix: bugs seguridad, bloqueos de horario, tab pagos, datos pago desde BD"
git push origin main   # Railway hace auto-deploy al detectar el push
```

Verificar en Railway que el build pase y el servicio quede en estado **Active**.

---

## PASO 4 — Flutter: verificar que las URLs apuntan a producción

El archivo `frontend/lib/core/constants/api_constants.dart` ya tiene activadas las URLs de Railway:

```dart
static String get baseUrl => '$_railwayUrl/api/v1';
static String get wsTimers => 'wss://pichangaya-production-0eb7.up.railway.app/ws/timers';
```

> Para volver a desarrollo local, comentar esas líneas y descomentar el bloque de localhost.

---

## PASO 5 — Flutter: build de producción

### Web (panel admin en Chrome/navegador)
```bash
cd frontend
flutter build web --release --web-renderer canvaskit
```
Los archivos quedan en `frontend/build/web/`. Subir a Railway Static, Vercel, Netlify, o Firebase Hosting.

### Android (APK para clientes)
```bash
cd frontend
flutter build apk --release --split-per-abi
```
APKs en `frontend/build/app/outputs/flutter-apk/`:
- `app-arm64-v8a-release.apk` → la mayoría de celulares modernos
- `app-armeabi-v7a-release.apk` → celulares más antiguos

### Android (App Bundle para Play Store)
```bash
cd frontend
flutter build appbundle --release
```

---

## PASO 6 — Smoke test en producción

Verificar estos endpoints después del deploy:

```bash
# Health check
curl https://pichangaya-production-0eb7.up.railway.app/health

# Datos de pago (endpoint nuevo)
curl https://pichangaya-production-0eb7.up.railway.app/api/v1/locales/configuracion/pagos

# Docs desactivados (debe devolver 404)
curl https://pichangaya-production-0eb7.up.railway.app/docs
```

---

## Checklist final antes de subir

### Backend
- [ ] `DEBUG=False` en Railway
- [ ] `ALLOWED_ORIGINS` actualizado en Railway
- [ ] Tabla `bloqueos_horario` creada (`python crear_tabla_bloqueos.py`)
- [ ] Push del código a main (Railway auto-deploya)
- [ ] Health check OK: `GET /health` → `{"status": "ok"}`
- [ ] Docs desactivados: `GET /docs` → 404

### Frontend
- [ ] `api_constants.dart` apuntando a Railway (ya aplicado)
- [ ] `flutter build web --release` sin errores
- [ ] `flutter build apk --release` sin errores
- [ ] Login funciona con usuario real
- [ ] Reserva de prueba completa (cancha → slot → pago → voucher)
- [ ] Panel admin: dashboard carga, bloqueos tab visible

---

## Para volver a desarrollo local (cuando quieras seguir programando)

1. En `api_constants.dart`: comentar líneas de Railway, descomentar bloque localhost
2. En `backend/.env`: ya tiene `DEBUG=True` y URLs localhost — no tocar
3. Levantar backend: `cd backend && venv\Scripts\activate && uvicorn app.main:app --reload --port 8000`
4. Levantar frontend: `flutter run -d chrome --web-port 3000`
