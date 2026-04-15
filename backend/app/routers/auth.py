from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token
)
from app.core.dependencies import get_current_user
from app.core.limiter import limiter
from app.models.user import User, RolEnum
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse,
    RefreshRequest, UserResponse
)

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    if data.email:
        result = await db.execute(
            select(User).where(User.email == data.email.lower()))
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="El correo ya esta registrado")
    result = await db.execute(
        select(User).where(User.celular == data.celular))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="El celular ya esta registrado")

    user = User(
        celular=data.celular,
        email=data.email.lower() if data.email else None,
        nombre=data.nombre,
        dni=data.dni,
        password_hash=hash_password(data.password),
        rol=RolEnum.cliente,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    access_token = create_access_token({"sub": str(user.id), "rol": user.rol.value})
    refresh_token, jti = create_refresh_token({"sub": str(user.id)})
    user.refresh_jti = jti
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        rol=user.rol.value,
        nombre=user.nombre,
        email=user.email,
        celular=user.celular,
    )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(request: Request, data: LoginRequest, db: AsyncSession = Depends(get_db)):
    login_val = data.login.strip()
    is_email = "@" in login_val
    if is_email:
        result = await db.execute(
            select(User).where(
                User.email == login_val.lower(),
                User.activo == True))
    else:
        celular = login_val.replace("+51", "").replace(" ", "").replace("-", "")
        result = await db.execute(
            select(User).where(
                User.celular == celular,
                User.activo == True))
    user = result.scalar_one_or_none()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

    access_token = create_access_token({"sub": str(user.id), "rol": user.rol.value})
    refresh_token, jti = create_refresh_token({"sub": str(user.id)})
    user.refresh_jti = jti
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        rol=user.rol.value,
        nombre=user.nombre,
        email=user.email,
        celular=user.celular,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_token(data.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Refresh token invalido")

    jti = payload.get("jti")
    result = await db.execute(
        select(User).where(User.id == payload["sub"], User.activo == True))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")

    # Verificar que el jti del token coincida con el guardado en BD
    if not jti or user.refresh_jti != jti:
        raise HTTPException(status_code=401, detail="Refresh token revocado o inválido")

    access_token = create_access_token({"sub": str(user.id), "rol": user.rol.value})
    new_refresh, new_jti = create_refresh_token({"sub": str(user.id)})
    user.refresh_jti = new_jti  # rotación — el token anterior queda inválido
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh,
        rol=user.rol.value,
        nombre=user.nombre,
        email=user.email,
        celular=user.celular,
    )


@router.post("/logout", status_code=204)
async def logout(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Invalida el refresh token del usuario. El access token expirará por su propio TTL."""
    result = await db.execute(select(User).where(User.id == current_user["id"]))
    user = result.scalar_one_or_none()
    if user:
        user.refresh_jti = None
        await db.commit()


@router.get("/me", response_model=UserResponse)
async def me(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(User).where(User.id == current_user["id"]))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return UserResponse(
        id=str(user.id),
        celular=user.celular,
        email=user.email,
        nombre=user.nombre,
        dni=user.dni,
        rol=user.rol.value,
        activo=user.activo,
    )
