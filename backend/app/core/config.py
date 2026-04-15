from pydantic_settings import BaseSettings
from pydantic import field_validator


class Settings(BaseSettings):

    APP_NAME: str = "PichangaYa API"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    IMGBB_API_KEY: str = ""
    YAPE_NUMERO: str = ""
    NUBEFACT_TOKEN: str = ""
    NUBEFACT_URL: str = "https://api.nubefact.com/api/v1"
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
