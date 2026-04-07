from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_token
from app.core.dependencies import get_current_user
from app.models.user import User, RolEnum
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, RefreshRequest, UserResponse

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Verificar celular único
    result = await db.execute(select(User).where(User.celular == data.celular))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="El celular ya está registrado")

    user = User(
        celular=data.celular,
        nombre=data.nombre,
        dni=data.dni,
        password_hash=hash_password(data.password),
        rol=RolEnum.cliente,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    access_token  = create_access_token({"sub": str(user.id), "rol": user.rol.value})
    refresh_token = create_refresh_token({"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        rol=user.rol.value,
        nombre=user.nombre,
        celular=user.celular,
    )


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    # Limpiar celular
    celular = data.celular.replace("+51", "").replace(" ", "").replace("-", "")

    result = await db.execute(
        select(User).where(User.celular == celular, User.activo == True)
    )
    user = result.scalar_one_or_none()

    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Celular o contraseña incorrectos")

    access_token  = create_access_token({"sub": str(user.id), "rol": user.rol.value})
    refresh_token = create_refresh_token({"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        rol=user.rol.value,
        nombre=user.nombre,
        celular=user.celular,
    )


@router.post("/refresh")
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_token(data.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Refresh token inválido")

    result = await db.execute(
        select(User).where(User.id == payload["sub"], User.activo == True)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")

    access_token  = create_access_token({"sub": str(user.id), "rol": user.rol.value})
    new_refresh   = create_refresh_token({"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh,
        rol=user.rol.value,
        nombre=user.nombre,
        celular=user.celular,
    )


@router.get("/me", response_model=UserResponse)
async def me(current_user: dict = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == current_user["id"]))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return user
