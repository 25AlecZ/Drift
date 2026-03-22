#!/usr/bin/env python3
"""
Drift - Step 0: Build a tone sample from the user's own iMessages in the past year.
Filters to only messages sent to recommended contacts, saving to tone_sample.md.
"""

import os
import sqlite3

CHAT_DB = os.path.expanduser("~/Library/Messages/chat.db")
TONE_SAMPLE_PATH = os.path.join(os.path.dirname(__file__), "tone_sample.md")


def build_tone_sample(contacts=None) -> str:
    """
    Pulls user-sent messages from the past year filtered to the given contacts.
    If no contacts provided, falls back to all 1-on-1 messages.
    Saves to tone_sample.md and returns content capped at ~60000 chars.
    """
    conn = sqlite3.connect(CHAT_DB)
    cursor = conn.cursor()

    if contacts:
        phones = [c["phone_or_email"] for c in contacts]
        placeholders = ",".join("?" * len(phones))
        cursor.execute(f"""
            SELECT DISTINCT m.text
            FROM message m
            JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            JOIN chat_handle_join chj ON cmj.chat_id = chj.chat_id
            JOIN handle h ON chj.handle_id = h.ROWID
            WHERE m.is_from_me = 1
              AND m.text IS NOT NULL
              AND length(m.text) > 5
              AND h.id IN ({placeholders})
            ORDER BY RANDOM()
            LIMIT 500
        """, phones)
    else:
        cursor.execute("""
            SELECT text FROM message
            WHERE is_from_me = 1
              AND cache_roomnames IS NULL
              AND NOT is_service_message
              AND text IS NOT NULL
              AND length(text) > 15
              AND (julianday('now','localtime') - julianday(
                    datetime(substr(date,1,9)+978307200,'unixepoch','localtime'))) <= 365
            ORDER BY RANDOM()
        """)

    rows = cursor.fetchall()
    conn.close()

    lines = [f'- "{row[0]}"' for row in rows]
    full_sample = "\n".join(lines)

    with open(TONE_SAMPLE_PATH, "w") as f:
        f.write("# My Message Tone Sample\n\n")
        source = f"{len(contacts)} recommended contacts" if contacts else "all 1-on-1 chats"
        f.write(f"Messages I've sent to {source} in the past year.\n\n---\n\n")
        f.write(full_sample)

    print(f"[Tone] Saved {len(rows)} messages to tone_sample.md")
    return full_sample[:60000]
