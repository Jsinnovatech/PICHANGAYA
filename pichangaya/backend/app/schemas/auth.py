from pydantic import BaseModel, field_validator
import re


class RegisterRequest(BaseModel):
    celular: str
    nombre: str
    password: str
    dni: str | None = None

    @field_validator("celular")
    @classmethod
    def validate_celular(cls, v):
        v = v.replace(" ", "").replace("-", "")
        if not re.match(r"^\d{9}$", v):
            raise ValueError("El celular debe tener 9 dígitos")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        if len(v) < 6:
            raise ValueError("La contraseña debe tener al menos 6 caracteres")
        return v


class LoginRequest(BaseModel):
    celular: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    rol: str
    nombre: str


class RefreshRequest(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id: str
    celular: str
    nombre: str
    dni: str | None
    rol: str
    activo: bool

    class Config:
        from_attributes = True
