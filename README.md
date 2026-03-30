# 🏟️ PichangaYa

Sistema de reservas de canchas de fútbol sintético — Zona Collique/Comas, Lima.

## Estructura del proyecto

```
pichangaya/
├── backend/     # FastAPI + Python — API REST + WebSockets
└── frontend/    # Flutter — App móvil Android/iOS
```

## Requisitos previos

- Python 3.11+
- Flutter SDK 3.x
- PostgreSQL (Railway)
- Git

## Setup rápido

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env       # Edita con tus credenciales
alembic upgrade head
uvicorn app.main:app --reload
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```
