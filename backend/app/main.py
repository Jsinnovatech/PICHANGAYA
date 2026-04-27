from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.core.config import settings
from app.core.limiter import limiter
from app.routers import auth, locales, reservas, pagos, admin, suscripcion, super_admin, notificaciones_router, websocket, horarios

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    # Docs solo visibles en modo DEBUG
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

# Rate limiter global
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS
# En DEBUG (desarrollo local) se acepta cualquier origen para no bloquear Flutter web.
# En producción se usan únicamente los orígenes del .env.
_raw_origins = [o.strip() for o in settings.ALLOWED_ORIGINS.split(",") if o.strip()]
_use_wildcard = settings.DEBUG or "*" in _raw_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if _use_wildcard else _raw_origins,
    allow_credentials=not _use_wildcard,   # credentials=True incompatible con wildcard
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,                   prefix=settings.API_V1_PREFIX)
app.include_router(locales.router,                prefix=settings.API_V1_PREFIX)
app.include_router(reservas.router,               prefix=settings.API_V1_PREFIX)
app.include_router(pagos.router,                  prefix=settings.API_V1_PREFIX)
app.include_router(admin.router,                  prefix=settings.API_V1_PREFIX)
app.include_router(suscripcion.router,            prefix=settings.API_V1_PREFIX)
app.include_router(super_admin.router,            prefix=settings.API_V1_PREFIX)
app.include_router(notificaciones_router.router,  prefix=settings.API_V1_PREFIX)
app.include_router(horarios.router,               prefix=settings.API_V1_PREFIX)
app.include_router(websocket.router)


@app.get("/")
async def root():
    return {"status": "ok"}


@app.get("/health")
async def health():
    return {"status": "ok"}
