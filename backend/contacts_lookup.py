import sqlite3
import glob
import re
import pathlib
from typing import Optional


def _normalize_phone(phone: str) -> str:
    """Strip all non-digit characters for comparison (e.g. '+1 (415) 555-0000' -> '14155550000')."""
    return re.sub(r"\D", "", phone)


def _find_addressbook_dbs() -> list:
    """Find all AddressBook SQLite database files (root + all Sources subdirectories)."""
    base = pathlib.Path.home() / "Library/Application Support/AddressBook"
    paths = glob.glob(str(base / "AddressBook-v22.abcddb"))
    paths += glob.glob(str(base / "Sources/*/AddressBook-v22.abcddb"))
    return paths


def build_contacts_map() -> dict[str, str]:
    """
    Read the macOS AddressBook database and return a mapping of
    normalized phone/email -> display name.

    Usage in imessage_extract.py:
        from contacts_lookup import build_contacts_map
        contacts_map = build_contacts_map()
        name = contacts_map.get(normalize_phone(handle), handle)  # fallback to raw handle

    Returns:
        dict where keys are:
          - normalized phone digits (e.g. "14155550000")
          - lowercase email addresses (e.g. "user@example.com")
        and values are display names (e.g. "Jake Smith")
    """
    db_paths = _find_addressbook_dbs()
    if not db_paths:
        print("[Contacts] AddressBook database not found. contact_name will fall back to phone/email.")
        return {}

    contacts_map = {}

    for db_path in db_paths:
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()

            # Build a map of record ID -> display name
            cursor.execute("""
                SELECT Z_PK,
                       COALESCE(ZFIRSTNAME, '') || ' ' || COALESCE(ZLASTNAME, '') AS full_name,
                       COALESCE(ZORGANIZATION, '') AS org
                FROM ZABCDRECORD
            """)
            name_map = {}
            for pk, full_name, org in cursor.fetchall():
                full_name = full_name.strip()
                name_map[pk] = full_name if full_name else org

            # Map phone numbers to display names
            cursor.execute("SELECT ZOWNER, ZFULLNUMBER FROM ZABCDPHONENUMBER")
            for owner_id, phone in cursor.fetchall():
                if phone and owner_id in name_map:
                    normalized = _normalize_phone(phone)
                    if normalized:
                        contacts_map[normalized] = name_map[owner_id]

            # Map email addresses to display names
            cursor.execute("SELECT ZOWNER, ZADDRESS FROM ZABCDEMAILADDRESS")
            for owner_id, email in cursor.fetchall():
                if email and owner_id in name_map:
                    contacts_map[email.lower()] = name_map[owner_id]

            conn.close()

        except Exception as e:
            print(f"[Contacts] ERROR reading {db_path}: {e}")

    print(f"[Contacts] Loaded {len(contacts_map)} phone/email entries from AddressBook.")
    return contacts_map


def resolve_name(handle: str, contacts_map: dict[str, str]) -> str:
    """
    Look up a display name for an iMessage handle (phone or email).
    Falls back to the raw handle if no match is found.

    Args:
        handle: phone number or email from iMessage (e.g. '+14155550000' or 'user@example.com')
        contacts_map: dict returned by build_contacts_map()

    Returns:
        Display name string, or the raw handle if not found in AddressBook
    """
    # Try email match first
    if "@" in handle:
        return contacts_map.get(handle.lower(), handle)

    # Try normalized phone match
    normalized = _normalize_phone(handle)
    # Try with and without leading country code 1
    name = contacts_map.get(normalized) or contacts_map.get(normalized.lstrip("1"))
    return name if name else handle


if __name__ == "__main__":
    print("=== Testing AddressBook Lookup ===\n")

    contacts_map = build_contacts_map()
    print(f"Total entries loaded: {len(contacts_map)}\n")

    if not contacts_map:
        print("No contacts loaded — check AddressBook permissions or DB path.")
    else:
        print("Sample entries (first 10):")
        for key, name in list(contacts_map.items())[:10]:
            print(f"  {key} -> {name}")

        print("\n=== Testing resolve_name ===")
        test_handles = [
            "+1 (415) 555-0000",   # formatted phone
            "test@example.com",    # email
            "15105550000",         # digits only
        ]
        for handle in test_handles:
            result = resolve_name(handle, contacts_map)
            print(f"  resolve_name('{handle}') -> '{result}'")
