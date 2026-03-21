import pathlib
import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_ACCOUNT_PATH = pathlib.Path(__file__).parent / "serviceAccountKey.json"


def init_firebase() -> firestore.Client:
    """Initialize Firebase Admin SDK and return Firestore client.
    Safe to call multiple times — reuses existing app if already initialized."""
    if not firebase_admin._apps:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT_PATH))
        firebase_admin.initialize_app(cred)
    return firestore.client()
