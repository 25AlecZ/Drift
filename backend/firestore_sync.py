from typing import List
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from firebase_init import init_firebase

FIRESTORE_COLLECTION = "nudges"


def _make_doc_id(phone_or_email: str) -> str:
    """Use phone/email as the document ID so re-runs update the same doc instead of creating duplicates."""
    return phone_or_email.replace("/", "_").strip()


def upsert_nudge(db, contact: dict) -> None:
    """Write one contact to Firestore.
    First write: creates the document, sets dismissed=False and created_at timestamp.
    Subsequent writes: refreshes all data fields, leaves dismissed and created_at untouched."""
    doc_id = _make_doc_id(contact["phone_or_email"])
    doc_ref = db.collection(FIRESTORE_COLLECTION).document(doc_id)

    update_data = {
        "contact_name":          contact["contact_name"],
        "phone_or_email":        contact["phone_or_email"],
        "days_since_contact":    contact["days_since_contact"],
        "total_messages":        contact["total_messages"],
        "drift_score":           contact["drift_score"],
        "last_message_preview":  contact.get("last_message_preview", ""),
        "talking_points":        contact.get("talking_points", []),
        "conversation_starters": contact.get("conversation_starters", []),
        "subtitle":              contact.get("subtitle", ""),
        # "dismissed" intentionally absent — preserves the user's dismiss action across re-runs
        # "created_at" intentionally absent — only set once on first write below
    }

    if not doc_ref.get().exists:
        update_data["created_at"] = SERVER_TIMESTAMP
        update_data["dismissed"] = False
        doc_ref.set(update_data)
    else:
        doc_ref.set(update_data, merge=True)


def sync_nudges_to_firestore(contacts: List[dict]) -> None:
    """Write the full list of enriched contacts to Firestore. Called by main.py."""
    db = init_firebase()
    success, errors = 0, 0

    for contact in contacts:
        try:
            upsert_nudge(db, contact)
            print(f"[Firestore] Synced: {contact['contact_name']} ({contact['phone_or_email']})")
            success += 1
        except Exception as e:
            print(f"[Firestore] ERROR syncing {contact.get('contact_name', 'unknown')}: {e}")
            errors += 1

    print(f"[Firestore] Done. {success} synced, {errors} errors.")
