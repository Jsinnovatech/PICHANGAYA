from pydantic import BaseModel, field_validator
from typing import Optional
import re


class RegisterRequest(BaseModel):
    nombre: str
    email: Optional[str] = None
    celular: str
    password: str
    dni: Optional[str] = None

    @field_validator("email")
    @classmethod
    def validate_email(cls, v):
        if not v or v.strip() == '':
            return None
        v = v.strip().lower()
        if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', v):
            raise ValueError("Email inválido")
        return v

    @field_validator("celular")
    @classmethod
    def validate_celular(cls, v):
        v = v.replace(" ", "").replace("-", "").replace("+51", "")
        if not re.match(r"^\d{9}$", v):
            raise ValueError("El celular debe tener 9 dígitos")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError("La contraseña debe tener al menos 8 caracteres")
        if not any(c.isdigit() for c in v):
            raise ValueError("La contraseña debe contener al menos un número")
        return v

    @field_validator("dni")
    @classmethod
    def validate_dni(cls, v):
        if v is None:
            return v
        v = v.strip()
        if v == '':
            return None
        if not re.match(r'^\d{8}$', v):
            raise ValueError("El DNI debe tener exactamente 8 dígitos numéricos")
        return v


class LoginRequest(BaseModel):
    login: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    rol: str
    nombre: str
    email: Optional[str] = None
    celular: Optional[str] = None


class RefreshRequest(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id: str
    celular: str
    email: Optional[str] = None
    nombre: str
    dni: Optional[str] = None
    rol: str
    activo: bool

    class Config:
        from_attributes = True