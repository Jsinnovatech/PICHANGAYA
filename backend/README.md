# PichangaYa — Backend (FastAPI)

## Setup local

```bash
# 1. Crear entorno virtual
python -m venv venv
source venv/bin/activate        # Linux/Mac
venv\Scripts\activate           # Windows

# 2. Instalar dependencias
pip install -r requirements.txt

# 3. Configurar variables de entorno
cp .env.example .env
# Edita .env con tu DATABASE_URL de Railway y SECRET_KEY

# 4. Correr migraciones
alembic upgrade head

# 5. Levantar servidor de desarrollo
uvicorn app.main:app --reload --port 8000
```

## Acceder a la documentación
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Estructura
```
backend/
├── app/
│   ├── core/           # Config, DB, seguridad, dependencias
│   ├── models/         # Modelos SQLAlchemy (tablas)
│   ├── schemas/        # Schemas Pydantic (request/response)
│   ├── routers/        # Endpoints de la API
│   ├── services/       # Lógica de negocio
│   └── utils/          # Utilidades
├── migrations/         # Migraciones Alembic
├── tests/              # Tests pytest
├── requirements.txt
├── alembic.ini
└── .env.example
```
