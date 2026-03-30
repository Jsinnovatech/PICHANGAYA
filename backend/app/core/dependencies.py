from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
# OAuth2PasswordBearer → lee el token JWT del header Authorization: Bearer <token>

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")
# tokenUrl → le dice al Swagger dónde hacer login para obtener un token
# Cuando el usuario hace login, el Swagger guarda el token automáticamente


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    # Depends(oauth2_scheme) → extrae el token del header Authorization
    # Si no hay header → FastAPI devuelve 401 automáticamente
    db: AsyncSession = Depends(get_db)
) -> dict:
    """
    Verifica el JWT y devuelve los datos del usuario autenticado.
    Se usa como dependencia en endpoints protegidos.
    """

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
        # Este header es requerido por el estándar OAuth2
    )

    # Decodificar y verificar el token
    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        raise credentials_exception
    # Si el token expiró o fue alterado, decode_token devuelve None

    user_id: str = payload.get("sub")
    if user_id is None:
        raise credentials_exception
    # "sub" es el campo estándar JWT para el ID del sujeto (usuario)

    # Buscar el usuario en la BD para verificar que sigue activo
    result = await db.execute(
        select(User).where(User.id == user_id, User.activo == True)
        # User.activo == True → si el admin desactiva la cuenta, pierde acceso inmediatamente
    )
    user = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception

    # Devolver dict con los datos necesarios para los endpoints
    return {
        "id": str(user.id),
        "celular": user.celular,
        "nombre": user.nombre,
        "rol": user.rol.value
        # .value extrae el string del enum: RolEnum.cliente → "cliente"
    }


async def require_admin(
    current_user: dict = Depends(get_current_user)
) -> dict:
    """
    Igual que get_current_user pero además verifica que el rol sea admin o super_admin.
    Se usa en endpoints del panel de administración.
    """
    if current_user.get("rol") not in ["admin", "super_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso solo para administradores"
        )
    return current_user