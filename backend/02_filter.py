#!/usr/bin/env python3
"""
Drift - Step 2: Hard cutoff filtering using message metadata only.
Eliminates obvious non-candidates before we read message content in step 3.
"""

import re
import sqlite3
import os

CHAT_DB = os.path.expanduser("~/Library/Messages/chat.db")

# Hard cutoff thresholds — adjust as needed
MIN_MESSAGES   = 50    # must have exchanged at least this many messages
MIN_DAYS_SILENT = 30   # must not have messaged in this many days
MAX_DAYS_SILENT = 1500 # ignore contacts silent for 4+ years (relationship likely dead)


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
    """Filter out short codes (businesses/SMS services) and obvious spam."""
    if re.fullmatch(r'\d{4,6}', contact_id):
        return False
    spam_indicators = ['hotmail.xyz', 'uigmail', 'faafp.cn', 'hd3-bu1', 'fdir-a1', 'solveit']
    if any(s in contact_id for s in spam_indicators):
        return False
    return True


def apply_hard_cutoffs(contacts):
    """Stage 1 filter — metadata only, no message content needed."""
    candidates = []

    for contact_id, total_messages, last_date, days_ago in contacts:
        if not is_real_contact(contact_id):
            continue
        if not days_ago:              # 0 or None = messaged today
            continue
        if total_messages < MIN_MESSAGES:
            continue
        if days_ago < MIN_DAYS_SILENT:
            continue
        if days_ago > MAX_DAYS_SILENT:
            continue

        candidates.append({
            "contact_id": contact_id,
            "total_messages": total_messages,
            "last_message_date": last_date,
            "days_since_contact": days_ago,
        })

    return candidates


def main():
    if not os.path.exists(CHAT_DB):
        print(f"ERROR: chat.db not found at {CHAT_DB}")
        print("Make sure Terminal has Full Disk Access.")
        return

    print("Reading iMessage database...\n")
    contacts = get_contact_stats()
    print(f"Total contacts found: {len(contacts)}")

    candidates = apply_hard_cutoffs(contacts)
    print(f"After hard cutoffs:   {len(candidates)}\n")

    print(f"{'Contact':<35} {'Messages':>8}  {'Days Silent':>11}")
    print("-" * 58)
    for c in candidates:
        display_id = c["contact_id"][:33] + ".." if len(c["contact_id"]) > 35 else c["contact_id"]
        print(f"{display_id:<35} {c['total_messages']:>8}  {c['days_since_contact']:>11}")


if __name__ == "__main__":
    main()
