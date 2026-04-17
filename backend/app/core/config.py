from pydantic_settings import BaseSettings
from pydantic import field_validator


class Settings(BaseSettings):

    # Nombre de la app — aparece en el Swagger UI
    APP_NAME: str = "PichangaYa API"

    # True muestra errores detallados — False en producción
    DEBUG: bool = False

    # Prefijo de todas las rutas: /api/v1/auth/login, /api/v1/locales, etc.
    API_V1_PREFIX: str = "/api/v1"

    # Dominios permitidos para conectarse — se lee como texto y se separa por comas
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    # URL de conexión a PostgreSQL — OBLIGATORIO en .env
    DATABASE_URL: str

    # Clave secreta para firmar los tokens JWT — OBLIGATORIO en .env
    SECRET_KEY: str

    # Algoritmo de firma del JWT
    ALGORITHM: str = "HS256"

    # Minutos que dura el token de acceso
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # Días que dura el refresh token
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # API key de imgbb para subir fotos de vouchers
    IMGBB_API_KEY: str = ""

    # Número de Yape para recibir pagos de suscripción
    YAPE_NUMERO: str = ""

    # Ruta al JSON de cuenta de servicio de Firebase (para enviar pushes FCM)
    FIREBASE_SERVICE_ACCOUNT_JSON: str = "firebase-service-account.json"

    # Token de Nubefact para facturación SUNAT — se configura en Fase 4
    NUBEFACT_TOKEN: str = ""

    # URL base de la API de Nubefact
    NUBEFACT_URL: str = "https://api.nubefact.com/api/v1"

    # Datos de la empresa para los comprobantes electrónicos
    EMPRESA_RUC: str = ""
    EMPRESA_RAZON_SOCIAL: str = ""
    EMPRESA_DIRECCION: str = ""

    @field_validator('SECRET_KEY')
    @classmethod
    def secret_key_min_length(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError('SECRET_KEY debe tener al menos 32 caracteres')
        return v

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()