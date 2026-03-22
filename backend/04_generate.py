#!/usr/bin/env python3
"""
Drift - Step 4: Call Gemini to generate talking points and conversation starters.

For each contact generates two parallel arrays:
- talking_points: short topic phrases for UI display (e.g. "His basketball league")
- conversation_starters: full ready-to-send messages in the user's tone, one per talking point
"""

import os
import json
import sqlite3
from google import genai
from google.genai import types

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


def _parse_json(text):
    """Strip markdown fences and parse JSON."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()
    return json.loads(text)


def _extract_text(response):
    """Extract text from a Gemini response, handling search grounding edge cases."""
    text = ""
    try:
        text = response.text or ""
    except Exception:
        pass
    if not text:
        for part in response.candidates[0].content.parts:
            if hasattr(part, "text") and part.text:
                text = part.text
                break
    return text


def _extract_interests(client, conversation):
    """Extract 3-5 interest keywords from the conversation."""
    prompt = f"""Read this conversation and list 3-5 specific interests, hobbies, or recurring topics as short keywords.
Respond with ONLY a JSON array of strings, no explanation.
Example: ["NBA", "startup investing", "hiking", "coffee"]

Conversation:
{conversation}"""
    response = client.models.generate_content(model=GEMINI_MODEL, contents=prompt)
    return _parse_json(response.text)


def _generate_talking_points(client, contact, conversation, interests):
    """Call 2a: generate 3 short topic phrases with Google Search grounding."""
    relationship_summary = contact.get("relationship_summary", "")
    prompt = f"""You are helping someone reconnect with a friend they've drifted from.

Relationship: {relationship_summary}
Shared interests: {', '.join(interests)}
Days since last message: {contact['days_since_contact']}

Recent conversation:
{conversation}

Search the web for current news or events related to their shared interests.
Then generate exactly 3 talking points:
- 2 should reference something real and current from the web (a game, story, event, release, news)
- 1 should be a specific shared memory or inside topic from their conversation that is still relevant today

Rules:
- Short punchy phrases, not full sentences
- Be specific, not generic
- The contemporary ones must be grounded in something you actually found via search

Respond with ONLY a JSON array of 3 strings, no explanation."""

    response = client.models.generate_content(
        model=GEMINI_MODEL,
        contents=prompt,
        config=types.GenerateContentConfig(
            tools=[types.Tool(google_search=types.GoogleSearch())]
        )
    )
    return _parse_json(_extract_text(response))[:3]


def _generate_conversation_starters(client, contact, topics, tone_sample):
    """Call 2b: write a full ready-to-send message for each topic, in the user's tone."""
    relationship_summary = contact.get("relationship_summary", "")
    topics_list = "\n".join(f"{i+1}. {t}" for i, t in enumerate(topics))

    prompt = f"""You are ghostwriting text messages for someone reconnecting with a friend they've drifted from.

Here are real messages they've sent to friends — match this tone, vocabulary, and style exactly:
{tone_sample}

---
Friend context: {relationship_summary}
Days since last message: {contact['days_since_contact']}

Write one complete, ready-to-send text message for each of these topics:
{topics_list}

Rules:
- Each message must be complete and ready to send immediately — no placeholders, no brackets, no [NAME]
- Match the sender's casual style from the examples above exactly
- 1-3 sentences max per message
- Do not start every message with "Hey" — vary the openers

Respond with ONLY a JSON array of {len(topics)} strings, no explanation."""

    response = client.models.generate_content(model=GEMINI_MODEL, contents=prompt)
    return _parse_json(response.text)[:len(topics)]


def _call_gemini(contact, conversation, tone_sample):
    """
    Three-step Gemini pipeline:
    1. Extract interests from conversation
    2. Generate 3 short topic phrases (with search grounding)
    3. Write a full message for each topic (in user's tone)
    Returns dict with 'talking_points' and 'conversation_starters'.
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise EnvironmentError("GEMINI_API_KEY environment variable not set.")

    client = genai.Client(api_key=api_key)

    interests = _extract_interests(client, conversation)
    print(f"[Gemini] Interests: {interests}")

    topics = _generate_talking_points(client, contact, conversation, interests)
    print(f"[Gemini] Topics: {topics}")

    starters = _generate_conversation_starters(client, contact, topics, tone_sample)
    print(f"[Gemini] Starters: {starters}")

    return {"talking_points": topics, "conversation_starters": starters}


def enrich_with_talking_points(contacts, tone_sample=""):
    """
    Takes filtered contact list, adds talking_points and conversation_starters to each dict.
    Falls back to [] if Gemini fails so the pipeline always completes.
    """
    for contact in contacts:
        print(f"[Gemini] Enriching: {contact.get('contact_name', contact['phone_or_email'])}")
        try:
            messages = _get_recent_messages(contact["phone_or_email"])
            conversation = _format_conversation(messages)
            result = _call_gemini(contact, conversation, tone_sample)
            contact["talking_points"] = result["talking_points"]
            contact["conversation_starters"] = result["conversation_starters"]
            print(f"[Gemini] ✓ Done")
        except Exception as e:
            print(f"[Gemini] ERROR: {e}")
            contact["talking_points"] = []
            contact["conversation_starters"] = []

    return contacts
