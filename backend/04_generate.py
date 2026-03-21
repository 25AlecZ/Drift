#!/usr/bin/env python3
"""
Drift - Step 3: Call Gemini to generate talking points for each drift candidate.
Takes the filtered contact list from 02_filter.py and enriches each with talking_points.
"""

import os
import json
import sqlite3
from google import genai

CHAT_DB = os.path.expanduser("~/Library/Messages/chat.db")
GEMINI_MODEL = "gemini-2.5-flash"
RECENT_MESSAGES_LIMIT = 100


def _get_recent_messages(contact_id):
    """Fetch the last N messages with a contact for Gemini context."""
    conn = sqlite3.connect(CHAT_DB)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT is_from_me, text
        FROM message
        JOIN handle ON message.handle_id = handle.ROWID
        WHERE
            handle.id = ?
            AND message.cache_roomnames IS NULL
            AND NOT message.is_service_message
            AND message.text IS NOT NULL
        ORDER BY message.date DESC
        LIMIT ?
    """, (contact_id, RECENT_MESSAGES_LIMIT))
    rows = cursor.fetchall()
    conn.close()
    return list(reversed(rows))  # chronological order


def _format_conversation(messages):
    lines = []
    for is_from_me, text in messages:
        speaker = "Me" if is_from_me else "Them"
        lines.append(f"{speaker}: {text}")
    return "\n".join(lines)


def _call_gemini(contact, conversation):
    """Ask Gemini for 3 talking points. Returns a list of strings."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise EnvironmentError("GEMINI_API_KEY environment variable not set.")

    client = genai.Client(api_key=api_key)
    relationship_summary = contact.get("relationship_summary", "")

    prompt = f"""You are helping someone figure out what to talk about when reconnecting with a friend they've drifted from.

Relationship: {relationship_summary}
Days since last message: {contact['days_since_contact']}
Total messages exchanged: {contact['total_messages']}

Recent conversation:
{conversation}

Based on the conversation history and relationship context, generate exactly 3 talking points — specific topics or things they could bring up when reaching out. These should be:
- Short, punchy phrases (not full sentences or example texts)
- Grounded in real things from the conversation (shared interests, inside jokes, recurring topics, life events mentioned)
- Things that would feel natural and personal, not generic

Respond with ONLY a JSON array of 3 strings, no explanation.
Example: ["His basketball league", "The road trip you both talked about planning", "Her new job in Austin"]"""

    response = client.models.generate_content(model=GEMINI_MODEL, contents=prompt)
    text = response.text.strip()

    # Strip markdown code fences if Gemini wraps response in them
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()

    return json.loads(text)[:3]


def enrich_with_talking_points(contacts):
    """
    Takes filtered contact list, adds talking_points to each dict.
    Falls back to [] if Gemini fails for a contact so the pipeline always completes.
    """
    for contact in contacts:
        contact_id = contact["phone_or_email"]
        print(f"[Gemini] Enriching: {contact_id}")
        try:
            messages = _get_recent_messages(contact_id)
            conversation = _format_conversation(messages)
            contact["talking_points"] = _call_gemini(contact, conversation)
            print(f"[Gemini] ✓ Done")
        except Exception as e:
            print(f"[Gemini] ERROR: {e}")
            contact["talking_points"] = []

    return contacts
