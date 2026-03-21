#!/usr/bin/env python3
"""
Drift - Main entry point.
Run this to extract contacts, generate talking points, and sync to Firestore.

Usage:
    cd backend/
    python3 main.py

    Requires: backend/.env with GEMINI_API_KEY and backend/serviceAccountKey.json
"""

import os
import importlib.util
from dotenv import load_dotenv

# Load .env from the backend/ folder
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


def load(filename):
    """Load a module from a file that starts with a number (e.g. 02_filter.py)."""
    path = os.path.join(os.path.dirname(__file__), filename)
    spec = importlib.util.spec_from_file_location(filename, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


filter_mod          = load("02_filter.py")
semantic_filter_mod = load("03_filter_semantic.py")
generate_mod        = load("04_generate.py")

from firestore_sync import sync_nudges_to_firestore
from contacts_lookup import build_contacts_map, resolve_name


def main():
    # Steps 1 & 2: Extract and hard-filter contacts from iMessage
    print("=== Steps 1 & 2: Extracting and filtering contacts ===")
    all_contacts = filter_mod.get_contact_stats()
    candidates = filter_mod.apply_hard_cutoffs(all_contacts)

    # Resolve contact names from macOS AddressBook
    contacts_map = build_contacts_map()

    # Rename fields and filter to saved contacts only
    enriched_candidates = []
    for c in candidates:
        c["phone_or_email"] = c.pop("contact_id")
        c["contact_name"]   = resolve_name(c["phone_or_email"], contacts_map)
        c["drift_score"]    = round(c["total_messages"] / c["days_since_contact"], 2)
        c.pop("last_message_date", None)

        # Skip if not in AddressBook (resolve_name returns raw handle if no match)
        if c["contact_name"] == c["phone_or_email"]:
            continue
        enriched_candidates.append(c)

    candidates = enriched_candidates
    print(f"Found {len(candidates)} candidates after hard cutoffs + contacts filter\n")

    # Step 3: Semantic filter — Gemini reads conversations and decides who's worth reconnecting with
    print("=== Step 3: Semantic filtering with Gemini ===")
    recommended = semantic_filter_mod.semantic_filter(candidates)

    # Step 4: Generate talking points for recommended contacts only
    print("=== Step 4: Generating talking points with Gemini ===")
    enriched = generate_mod.enrich_with_talking_points(recommended)
    print()

    # Step 5: Sync to Firestore
    print("=== Step 5: Syncing to Firestore ===")
    sync_nudges_to_firestore(enriched)


if __name__ == "__main__":
    main()
