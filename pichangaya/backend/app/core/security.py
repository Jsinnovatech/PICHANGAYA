import bcrypt
# bcrypt es el algoritmo de hashing más seguro para contraseñas
# Funciona aplicando un "factor de coste" que lo hace lento a propósito
# Así los ataques de fuerza bruta tardan años en vez de segundos

from datetime import datetime, timedelta, timezone
# datetime → para trabajar con fechas y horas
# timedelta → para sumar tiempo (ej: "ahora + 60 minutos")
# timezone → para manejar zonas horarias correctamente

from typing import Optional
# Optional[X] significa que el valor puede ser X o None

from jose import JWTError, jwt
# jose → librería para crear y verificar tokens JWT
# JWTError → excepción que se lanza cuando un token es inválido
# jwt → objeto con los métodos encode() y decode()

from app.core.config import settings
# Importamos la configuración para usar SECRET_KEY y ALGORITHM


def hash_password(password: str) -> str:
    # Convierte una contraseña en texto plano a un hash seguro
    # Ejemplo: "cliente123" → "$2b$12$abc123..."
    # El hash siempre es diferente aunque la contraseña sea igual
    # porque bcrypt agrega un "salt" aleatorio automáticamente

    password_bytes = password.encode("utf-8")
    # encode("utf-8") convierte el texto a bytes
    # bcrypt trabaja con bytes, no con texto

    salt = bcrypt.gensalt()
    # gensalt() genera un salt aleatorio
    # El salt se incluye en el hash resultante
    # Por eso el mismo password siempre produce hashes distintos

    hashed = bcrypt.hashpw(password_bytes, salt)
    # hashpw() aplica bcrypt al password con el salt
    # El resultado incluye: algoritmo + coste + salt + hash

    return hashed.decode("utf-8")
    # decode("utf-8") convierte los bytes de vuelta a texto
    # para poder guardarlo en PostgreSQL como VARCHAR


def verify_password(plain_password: str, hashed_password: str) -> bool:
    # Verifica si una contraseña coincide con su hash
    # Devuelve True si coinciden, False si no
    # Se usa en el login: verify_password("cliente123", hash_guardado)

    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        # encode() convierte el texto ingresado a bytes

        hashed_password.encode("utf-8")
        # encode() convierte el hash guardado en BD a bytes
    )
    # checkpw() extrae el salt del hash, lo aplica al password ingresado
    # y compara el resultado con el hash guardado


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    # Crea un token JWT de acceso
    # data → información a incluir en el token (ej: {"sub": "uuid-del-usuario", "rol": "cliente"})
    # expires_delta → tiempo de vida del token (por defecto 60 minutos)

    to_encode = data.copy()
    # Copiamos el dict para no modificar el original

    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    # datetime.now(timezone.utc) → fecha/hora actual en UTC
    # Si no se pasa expires_delta, usa el valor del .env (60 minutos)

    to_encode.update({
        "exp": expire,
        # "exp" → fecha de expiración, el estándar JWT la usa para invalidar tokens
        "type": "access"
        # "type" → campo custom para distinguir access token del refresh token
    })

    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    # jwt.encode() firma el token con la SECRET_KEY usando el algoritmo HS256
    # El resultado es una cadena como: "eyJhbGc..."


def create_refresh_token(data: dict) -> str:
    # Crea un token JWT de refresco — dura más tiempo (30 días)
    # Se usa para obtener un nuevo access token sin hacer login de nuevo

    to_encode = data.copy()

    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    # Los refresh tokens duran 30 días según el .env

    to_encode.update({
        "exp": expire,
        "type": "refresh"
        # "type": "refresh" distingue este token del access token
    })

    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    # Decodifica y verifica un token JWT
    # Devuelve el contenido del token si es válido
    # Devuelve None si el token es inválido o expiró

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            # Usa la misma SECRET_KEY con la que se firmó
            algorithms=[settings.ALGORITHM]
            # algorithms es una lista — acepta HS256
        )
        return payload
        # payload es el dict original: {"sub": "uuid", "rol": "cliente", "exp": ...}

    except JWTError:
        return None
        # Si el token fue alterado, expiró o es inválido → devuelve None