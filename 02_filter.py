#!/usr/bin/env python3
"""
Drift - Step 2: Filter contacts and score them for drift.
Reads chat.db directly and narrows down to real drift candidates.
"""

import re
import sqlite3
import os

CHAT_DB = os.path.expanduser("~/Library/Messages/chat.db")

# Tunable thresholds
MIN_MESSAGES = 50        # must have exchanged at least this many messages total
MIN_DAYS_SILENT = 30     # must not have messaged in this many days
MAX_DAYS_SILENT = 1500   # ignore contacts you haven't talked to in 4+ years
TOP_N = 15               # number of drift candidates to surface


def get_contact_stats():
    conn = sqlite3.connect(CHAT_DB)
    cursor = conn.cursor()
    # Apple epoch offset: 978307200 (seconds between 1970-01-01 and 2001-01-01)
    cursor.execute("""
        SELECT
            handle.id AS contact_id,
            COUNT(message.ROWID) AS total_messages,
            datetime(MAX(substr(message.date, 1, 9)) + 978307200, 'unixepoch', 'localtime') AS last_message_date,
            CAST(
                (julianday('now', 'localtime') - julianday(datetime(MAX(substr(message.date, 1, 9)) + 978307200, 'unixepoch', 'localtime')))
            AS INTEGER) AS days_since_contact
        FROM message
        JOIN handle ON message.handle_id = handle.ROWID
        WHERE
            message.cache_roomnames IS NULL
            AND NOT message.is_service_message
        GROUP BY handle.id
        ORDER BY total_messages DESC
    """)
    contacts = cursor.fetchall()
    conn.close()
    return contacts


def is_real_contact(contact_id):
    """Filter out short codes (businesses) and obvious spam."""
    # Short codes: 4-6 digit numbers (SMS services, e.g. 85638, 26266)
    if re.fullmatch(r'\d{4,6}', contact_id):
        return False
    # Sketchy email domains
    spam_indicators = ['hotmail.xyz', 'uigmail', 'faafp.cn', 'hd3-bu1', 'fdir-a1', 'solveit']
    if any(s in contact_id for s in spam_indicators):
        return False
    return True


def drift_score(total_messages, days_since_contact):
    """
    Score how much a contact has drifted.
    Higher = used to talk a lot, haven't in a while.
    Formula is pluggable — easy to swap out later.
    """
    return total_messages / days_since_contact


def get_drift_candidates():
    contacts = get_contact_stats()
    candidates = []

    for contact_id, total_messages, last_date, days_ago in contacts:
        if not is_real_contact(contact_id):
            continue
        if not days_ago:  # None or 0 = messaged today
            continue
        if total_messages < MIN_MESSAGES:
            continue
        if days_ago < MIN_DAYS_SILENT:
            continue
        if days_ago > MAX_DAYS_SILENT:
            continue

        score = drift_score(total_messages, days_ago)
        candidates.append({
            "contact_id": contact_id,
            "total_messages": total_messages,
            "last_message_date": last_date,
            "days_since_contact": days_ago,
            "drift_score": round(score, 2),
        })

    candidates.sort(key=lambda x: x["drift_score"], reverse=True)
    return candidates[:TOP_N]


def main():
    if not os.path.exists(CHAT_DB):
        print(f"ERROR: chat.db not found at {CHAT_DB}")
        print("Make sure Terminal has Full Disk Access.")
        return

    print("Reading iMessage database...\n")
    candidates = get_drift_candidates()
    print(f"Top {len(candidates)} drift candidates:\n")

    print(f"{'Contact':<35} {'Messages':>8}  {'Days Silent':>11}  {'Drift Score':>11}")
    print("-" * 72)
    for c in candidates:
        display_id = c["contact_id"][:33] + ".." if len(c["contact_id"]) > 35 else c["contact_id"]
        print(f"{display_id:<35} {c['total_messages']:>8}  {c['days_since_contact']:>11}  {c['drift_score']:>11.2f}")


if __name__ == "__main__":
    main()
