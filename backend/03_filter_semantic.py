#!/usr/bin/env python3
"""
Drift - Step 3: Semantic filtering using Gemini.
Reads the last 100 messages per contact and asks Gemini whether this is
a relationship worth rekindling. Only contacts that pass move on to step 4.
"""

import os
import json
import sqlite3
from google import genai

CHAT_DB = os.path.expanduser("~/Library/Messages/chat.db")
GEMINI_MODEL = "gemini-2.5-flash"
RECENT_MESSAGES_LIMIT = 100


def _get_recent_messages(contact_id):
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


def _should_reconnect(contact, conversation):
    """
    Ask Gemini whether this relationship is worth rekindling.
    Returns a dict with: recommend (bool), reason (str), relationship_summary (str)
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise EnvironmentError("GEMINI_API_KEY environment variable not set.")

    client = genai.Client(api_key=api_key)

    prompt = f"""You are analyzing an iMessage conversation to decide if two people should reconnect.

Stats:
- Days since last message: {contact['days_since_contact']}
- Total messages exchanged: {contact['total_messages']}

Conversation history (most recent {RECENT_MESSAGES_LIMIT} messages):
{conversation}

Analyze this conversation and answer:
1. Does this look like a genuine friendship worth rekindling? Consider:
   - Did the conversation end naturally or on bad terms?
   - Was the relationship warm and mutual, or one-sided?
   - Are there shared interests, inside jokes, or meaningful topics?
2. Summarize the relationship in one sentence.

Respond with ONLY a JSON object, no explanation:
{{
  "recommend": true or false,
  "reason": "one sentence explaining why or why not",
  "relationship_summary": "one sentence describing the relationship (e.g. close college friends who bonded over basketball and travel)"
}}"""

    response = client.models.generate_content(model=GEMINI_MODEL, contents=prompt)
    text = response.text.strip()

    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()

    return json.loads(text)


def semantic_filter(contacts):
    """
    Stage 2 filter — uses Gemini to read conversation content.
    Returns only contacts Gemini recommends reconnecting with,
    enriched with relationship_summary for use in step 4.
    """
    recommended = []

    for contact in contacts:
        contact_id = contact["phone_or_email"]
        print(f"[Semantic Filter] Analyzing: {contact_id}")
        try:
            messages = _get_recent_messages(contact_id)
            conversation = _format_conversation(messages)
            result = _should_reconnect(contact, conversation)

            if result["recommend"]:
                contact["relationship_summary"] = result["relationship_summary"]
                recommended.append(contact)
                print(f"[Semantic Filter] ✓ Recommended — {result['reason']}")
            else:
                print(f"[Semantic Filter] ✗ Skipped — {result['reason']}")

        except Exception as e:
            print(f"[Semantic Filter] ERROR for {contact_id}: {e}")
            # On error, skip the contact to be safe

    print(f"\n[Semantic Filter] {len(recommended)}/{len(contacts)} contacts recommended\n")
    return recommended
