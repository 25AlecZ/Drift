#!/usr/bin/env python3
"""
Drift - Main entry point.
Run this to extract contacts, generate talking points, and sync to Firestore.

Usage:
    cd backend/
    export GEMINI_API_KEY="your-key-here"
    python3 main.py
"""

import sys
import os
import importlib.util

def load(filename):
    """Load a module from a file that starts with a number (e.g. 02_filter.py)."""
    path = os.path.join(os.path.dirname(__file__), filename)
    spec = importlib.util.spec_from_file_location(filename, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

filter_mod   = load("02_filter.py")
generate_mod = load("03_generate.py")

from firestore_sync import sync_nudges_to_firestore
from contacts_lookup import build_contacts_map, resolve_name


def main():
    # Steps 1 & 2: Extract and filter contacts from iMessage
    print("=== Steps 1 & 2: Extracting and filtering contacts ===")
    all_contacts = filter_mod.get_contact_stats()
    candidates = filter_mod.apply_hard_cutoffs(all_contacts)

    # Resolve contact names from macOS AddressBook
    contacts_map = build_contacts_map()

    # Rename fields to match the Firestore data contract
    for c in candidates:
        c["phone_or_email"] = c.pop("contact_id")
        c["contact_name"]   = resolve_name(c["phone_or_email"], contacts_map)
        c["drift_score"]    = round(c["total_messages"] / c["days_since_contact"], 2)
        c.pop("last_message_date", None)

    print(f"Found {len(candidates)} drift candidates\n")

    # Step 3: Enrich with Gemini talking points
    print("=== Step 3: Generating talking points with Gemini ===")
    enriched = generate_mod.enrich_with_talking_points(candidates)
    print()

    # Step 4: Sync to Firestore
    print("=== Step 4: Syncing to Firestore ===")
    sync_nudges_to_firestore(enriched)


if __name__ == "__main__":
    main()
