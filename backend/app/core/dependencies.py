from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> dict:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        raise credentials_exception

    user_id: str = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    # Leer usuario + rol directo desde BD (no del JWT)
    # Así un cambio de rol o desactivación surte efecto de inmediato
    result = await db.execute(
        select(User).where(User.id == user_id, User.activo == True)
    )
    user = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception

    return {
        "id": str(user.id),
        "celular": user.celular,
        "nombre": user.nombre,
        "rol": user.rol.value,  # siempre desde BD, nunca del JWT
    }


async def require_admin(
    current_user: dict = Depends(get_current_user)
) -> dict:
    if current_user.get("rol") not in ["admin", "super_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso solo para administradores"
        )
    return current_user


