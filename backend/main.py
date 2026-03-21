import sys
import os
import importlib.util

# Load 02_filter.py (importlib needed because filename starts with a digit)
_filter_path = os.path.join(os.path.dirname(__file__), "02_filter.py")
_spec = importlib.util.spec_from_file_location("filter02", _filter_path)
_filter_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_filter_mod)
get_drift_candidates = _filter_mod.get_drift_candidates

from contacts_lookup import build_contacts_map, resolve_name
from firestore_sync import sync_nudges_to_firestore


def build_nudges() -> list:
    """
    Pull drift candidates from iMessage, resolve contact names,
    and shape into the Firestore nudge schema.
    """
    print("[Drift] Loading contacts from AddressBook...")
    contacts_map = build_contacts_map()

    print("[Drift] Extracting drift candidates from iMessage...")
    candidates = get_drift_candidates()
    print(f"[Drift] Found {len(candidates)} drift candidates.")

    nudges = []
    for c in candidates:
        handle = c["contact_id"]
        name = resolve_name(handle, contacts_map)
        nudges.append({
            "contact_name":          name,
            "phone_or_email":        handle,
            "days_since_contact":    c["days_since_contact"],
            "total_messages":        c["total_messages"],
            "drift_score":           c["drift_score"],
            "last_message_preview":  "",   # TODO: add when teammate extracts last message text
            "talking_points":        [],   # TODO: add when Gemini enrichment is implemented
        })

    return nudges


def main():
    print("[Drift] Starting pipeline...\n")
    nudges = build_nudges()

    print(f"\n[Drift] Preview of nudges to sync:")
    print(f"{'Name':<25} {'Handle':<20} {'Days':>5} {'Score':>7}")
    print("-" * 60)
    for n in nudges:
        print(f"{n['contact_name']:<25} {n['phone_or_email']:<20} {n['days_since_contact']:>5} {n['drift_score']:>7.2f}")

    print(f"\n[Drift] Syncing {len(nudges)} nudges to Firestore...")
    sync_nudges_to_firestore(nudges)


if __name__ == "__main__":
    main()
