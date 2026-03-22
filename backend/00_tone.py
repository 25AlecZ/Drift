#!/usr/bin/env python3
"""
Drift - Step 0: Build a tone sample from the user's own iMessages in the past year.
Saves to tone_sample.md and returns the content as a string for use in generation.
"""

import os
import sqlite3

CHAT_DB = os.path.expanduser("~/Library/Messages/chat.db")
TONE_SAMPLE_PATH = os.path.join(os.path.dirname(__file__), "tone_sample.md")


def build_tone_sample() -> str:
    """
    Pulls all user-sent messages from the past year, saves to tone_sample.md,
    and returns the content (capped at ~4000 chars for Gemini context).
    """
    conn = sqlite3.connect(CHAT_DB)
    cursor = conn.cursor()
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
        f.write("Real messages I've sent to friends in the past year.\n\n---\n\n")
        f.write(full_sample)

    print(f"[Tone] Saved {len(rows)} messages to tone_sample.md")

    # Cap what we return for use in Gemini prompts
    return full_sample[:4000]
