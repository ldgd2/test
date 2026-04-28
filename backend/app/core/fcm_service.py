import firebase_admin
from firebase_admin import credentials, messaging

cred = credentials.Certificate("firebase-key.json")
firebase_admin.initialize_app(cred)

def enviar_push(fcm_token: str, titulo: str, cuerpo: str, datos: dict = {}):
    try:
        message = messaging.Message(
            notification = messaging.Notification(title=titulo, body=cuerpo),
            data         = {k: str(v) for k, v in datos.items()},
            token        = fcm_token,
        )
        messaging.send(message)
        print(f"✅ Push enviado a {fcm_token[:20]}...")
    except Exception as e:
        print(f"❌ Error FCM: {e}")