from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers import auth, locales, reservas, pagos, admin, suscripcion, super_admin, notificaciones_router, websocket

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
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
app.include_router(websocket.router)


@app.get("/")
async def root():
    return {
        "app": settings.APP_NAME,
        "version": "1.0.0",
        "docs": "/docs",
        "status": "✅ Online",
    }


@app.get("/health")
async def health():
    return {"status": "ok"}