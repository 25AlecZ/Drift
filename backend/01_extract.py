#!/usr/bin/env python3
"""
Drift - Step 1: Read iMessage chat.db and list contacts with message stats.
Requires Full Disk Access granted to Terminal.
"""

import sqlite3
import os
from datetime import datetime

CHAT_DB = os.path.expanduser("~/Library/Messages/chat.db")

def get_contact_stats(db_path):
    """Query chat.db for all contacts with message counts and last message date."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get all contacts with their message stats
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


def main():
    if not os.path.exists(CHAT_DB):
        print(f"ERROR: chat.db not found at {CHAT_DB}")
        print("Make sure you're on macOS and have granted Full Disk Access to Terminal.")
        return

    print("Reading iMessage database...\n")
    contacts = get_contact_stats(CHAT_DB)

    print(f"Found {len(contacts)} contacts\n")
    print(f"{'Contact':<35} {'Messages':>8}  {'Last Message':<20} {'Days Ago':>8}")
    print("-" * 75)

    for contact_id, total_messages, last_date, days_ago in contacts:
        # Truncate long contact IDs for display
        display_id = contact_id[:33] + ".." if len(contact_id) > 35 else contact_id
        print(f"{display_id:<35} {total_messages:>8}  {last_date or 'N/A':<20} {days_ago or 'N/A':>8}")


if __name__ == "__main__":
    main()
