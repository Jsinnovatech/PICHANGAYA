import firebase_admin
from firebase_admin import credentials, messaging
import os

# Ruta absoluta directa al archivo
SERVICE_ACCOUNT_PATH = os.path.join(
    os.path.dirname(  # backend/
        os.path.dirname(  # app/
            os.path.dirname(  # core/
                os.path.abspath(__file__)
            )
        )
    ),
    "firebase-service-account.json"
)

print(f"Buscando credencial en: {SERVICE_ACCOUNT_PATH}")

# Inicializar Firebase solo una vez
if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)


def enviar_notificacion(token: str, titulo: str, cuerpo: str, data: dict = None):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=titulo,
                body=cuerpo,
            ),
            data=data or {},
            token=token,
        )
        response = messaging.send(message)
        print(f"✅ Notificación enviada: {response}")
        return True
    except Exception as e:
        print(f"❌ Error enviando notificación: {e}")
        return False