import firebase_admin
from firebase_admin import credentials, messaging
import os
import json

_firebase_ok = False

def _init_firebase():
    global _firebase_ok
    if firebase_admin._apps:
        _firebase_ok = True
        return

    # Opción 1: variable de entorno con el JSON completo
    service_account_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON_CONTENT")
    if service_account_json:
        try:
            cred = credentials.Certificate(json.loads(service_account_json))
            firebase_admin.initialize_app(cred)
            _firebase_ok = True
            print("✅ Firebase inicializado desde variable de entorno")
            return
        except Exception as e:
            print(f"❌ Error inicializando Firebase desde env var: {e}")

    # Opción 2: archivo local
    service_account_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "firebase-service-account.json"
    )
    if os.path.exists(service_account_path):
        try:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            _firebase_ok = True
            print(f"✅ Firebase inicializado desde archivo: {service_account_path}")
        except Exception as e:
            print(f"❌ Error inicializando Firebase desde archivo: {e}")
    else:
        print("⚠️  Firebase no configurado — notificaciones push deshabilitadas")

_init_firebase()


def enviar_notificacion(token: str, titulo: str, cuerpo: str, data: dict = None):
    if not _firebase_ok:
        print("⚠️  Firebase no inicializado, notificación omitida")
        return False
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