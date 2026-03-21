# Drift Backend — Full Documentation

## What This Does

The backend is a Python pipeline that runs locally on a Mac. It:
1. Reads your iMessage history from `~/Library/Messages/chat.db`
2. Scores contacts by how much you've drifted from them
3. Calls Google Gemini to generate personalized conversation starters
4. Writes everything to Firebase Firestore
5. The iOS app reads Firestore in real time and shows you nudges

Run it manually with `python3 main.py` whenever you want to refresh your nudges.

---

## File Ownership

| File                  | Owner             | Responsibility                                        |
|-----------------------|-------------------|-------------------------------------------------------|
| `imessage_extract.py` | iMessage teammate | Read chat.db, score contacts, return list of dicts    |
| `gemini_enrich.py`    | iMessage teammate | Call Gemini API, add talking_points to each contact   |
| `firebase_init.py`    | Firebase teammate | Initialize Firebase Admin SDK with service account key|
| `firestore_sync.py`   | Firebase teammate | Write/update nudge documents in Firestore             |
| `main.py`             | Shared            | Entry point — wires all modules together              |

**Rule: only edit files you own.** `main.py` is the only shared file — keep changes there minimal.

---

## How to Run

```bash
cd backend
export GEMINI_API_KEY="your-key-here"
python3 main.py
```

**Prerequisites:**
- `serviceAccountKey.json` in the `backend/` folder
  - Get it from: Firebase Console → Project Settings → Service Accounts → Generate new private key
  - Never commit this file (it's gitignored)
- Python dependencies: `pip install -r requirements.txt`
- Full Disk Access for Terminal: System Settings → Privacy & Security → Full Disk Access

---

## Data Flow

```
imessage_extract.py            gemini_enrich.py              firestore_sync.py
  get_contacts()      ──────▶  enrich_contacts()   ─────▶  sync_nudges_to_firestore()
                                                                      │
  Returns list[dict]           Adds talking_points                    ▼
  (contact info +              to each contact dict          Firestore "nudges"
   drift scores)                                             collection
                                                                      │
                                                                      ▼
                                                             iOS app (real-time
                                                             Firestore listener)
```

Step by step:
1. `get_contacts()` reads `~/Library/Messages/chat.db` via SQLite and returns scored contacts
2. `enrich_contacts()` loops over those contacts, calls Gemini for each, adds `talking_points`
3. `sync_nudges_to_firestore()` upserts each enriched contact into the Firestore `nudges` collection

---

## Data Contract Between Modules

All modules pass data as a `list[dict]`. Full schema:

| Field                  | Type        | Added by            | Description                                          |
|------------------------|-------------|---------------------|------------------------------------------------------|
| `contact_name`         | `str`       | iMessage teammate   | Display name from iMessage                           |
| `phone_or_email`       | `str`       | iMessage teammate   | Unique identifier; used as Firestore document ID     |
| `days_since_contact`   | `int`       | iMessage teammate   | Days since last message                              |
| `total_messages`       | `int`       | iMessage teammate   | Total message count with this person                 |
| `drift_score`          | `float`     | iMessage teammate   | `total_messages / days_since_contact` — higher = more urgent |
| `last_message_preview` | `str`       | iMessage teammate   | Preview of the last message sent/received            |
| `talking_points`       | `list[str]` | iMessage teammate   | 3 AI-generated conversation starters (added by Gemini)|
| `dismissed`            | `bool`      | Firebase teammate   | Set to `False` on first Firestore write; never reset after |
| `created_at`           | timestamp   | Firebase teammate   | Server timestamp on first Firestore write only       |

---

## Firestore Schema

**Collection:** `nudges`
**Document ID:** sanitized `phone_or_email` (e.g., `+14155550000`)

```json
{
  "contact_name": "Jake",
  "phone_or_email": "+14155550000",
  "days_since_contact": 67,
  "total_messages": 342,
  "drift_score": 5.1,
  "talking_points": [
    "Hey! How's the new job going?",
    "We should grab coffee soon",
    "I was just thinking about that trip we took — good times!"
  ],
  "last_message_preview": "Yeah let's hang soon",
  "dismissed": false,
  "created_at": "<server timestamp>"
}
```

**Re-run behavior:**
- Re-running `main.py` is always safe — updates existing docs, never creates duplicates
- `dismissed` is never reset — if the user dismisses a nudge in the iOS app, it stays dismissed
- `created_at` is never overwritten — always reflects when a contact first appeared

---

## Module Details

### `firebase_init.py`
- Loads `serviceAccountKey.json` from the same directory as the script (no hardcoded paths)
- Calls `firebase_admin.initialize_app()` once, guarded against double-init
- Returns a `firestore.Client` instance used by `firestore_sync.py`

### `firestore_sync.py`
- Uses `phone_or_email` as the Firestore document ID — deterministic, no duplicates across re-runs
- **First write**: creates doc with all fields + `dismissed=False` + `created_at=SERVER_TIMESTAMP`
- **Subsequent writes**: `set(data, merge=True)` — updates only provided fields, leaving `dismissed` and `created_at` untouched
- Each contact is wrapped in try/except — one bad entry won't stop the rest of the sync

### `gemini_enrich.py`
- **iMessage teammate's file** — implement `enrich_contacts()` here, do not modify other files
- Requires `GEMINI_API_KEY` env var (see How to Run above)
- Uses `gemini-1.5-flash` model — fast and cost-efficient
- Sends contact context (name, days since contact, message preview) and asks for 3 conversation starters as a JSON array
- Falls back to `talking_points: []` if Gemini fails for a specific contact, so the sync always completes

### `imessage_extract.py`
- **iMessage teammate's file** — implement `get_contacts()` here, do not modify other files
- Must return a list of dicts with all fields in the data contract above (except `talking_points`, `dismissed`, `created_at` — those are added later)
- Database path: `~/Library/Messages/chat.db`
- Apple timestamp epoch offset: add `978307200` to convert Apple timestamps to Unix time

---

## Environment Variables

| Variable         | Required | Description              |
|------------------|----------|--------------------------|
| `GEMINI_API_KEY` | Yes      | Google AI Studio API key |

Firebase credentials come from `serviceAccountKey.json`, not an env var.

---

## Testing Without iMessage Data

You can test the Firestore sync and Gemini enrichment independently before the iMessage extraction is built:

```bash
cd backend
python3 -c "
from gemini_enrich import enrich_contacts
from firestore_sync import sync_nudges_to_firestore

test_contacts = [{
    'contact_name': 'Test User',
    'phone_or_email': '+10000000000',
    'days_since_contact': 30,
    'total_messages': 100,
    'drift_score': 3.3,
    'last_message_preview': 'hey lets hang soon'
}]

enriched = enrich_contacts(test_contacts)
sync_nudges_to_firestore(enriched)
"
```

Then open Firebase Console → Firestore → `nudges` collection to verify the document was created.
Run it a second time to confirm `dismissed` and `created_at` are unchanged (merge behavior).
