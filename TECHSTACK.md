# Drift - Tech Stack

## What We're Building
A Mac + iOS app that reads your iMessage history, identifies friends you're drifting from, and nudges you to reach out with AI-generated talking points.

## Architecture

```
Mac (Python script)          iOS (SwiftUI app)
┌─────────────────┐         ┌─────────────────────┐
│ Read chat.db    │         │ Nudge List Screen    │
│ Score contacts  │──JSON──▶│ Nudge Detail Screen  │
│ Call Gemini API │         │ Keep / Remove / Send │
└─────────────────┘         └─────────────────────┘
```

## Mac Side — Data Extraction

| Component | Tech | Why |
|-----------|------|-----|
| Language | **Python 3** | Fast to write, great library support |
| iMessage access | **sqlite3** (stdlib) | chat.db is a SQLite database at `~/Library/Messages/chat.db` |
| AI | **Google Gemini API** (`google-generativeai` package) | Generates talking points from message history |
| Output | **JSON file** | Simple, no server needed for hackathon |

### Requirements
- macOS with Full Disk Access granted to Terminal (System Settings → Privacy & Security → Full Disk Access)
- Python 3.10+
- Gemini API key (get one at https://makersuite.google.com/app/apikey)

### Key files
- `extract.py` — main script
- `requirements.txt` — Python dependencies
- `nudges.json` — generated output (don't commit this, has personal data)

## iOS Side — User-Facing App

| Component | Tech | Why |
|-----------|------|-----|
| Framework | **SwiftUI** | Modern, declarative, fast to build |
| Min target | **iOS 17** | Latest SwiftUI features |
| Data | **Bundle JSON + UserDefaults** | Load nudges from bundled file, store dismiss state locally |
| Messaging | **URL scheme (`sms:`)** | Opens iMessage to a contact directly |

### Key screens
1. **Nudge List** — cards showing friends to reach out to
2. **Nudge Detail** — talking points + keep/remove/send buttons

## Data Flow

1. Run `python3 extract.py` on Mac (needs Full Disk Access)
2. Script reads iMessage database, scores contacts, calls Gemini
3. Outputs `nudges.json`
4. Copy `nudges.json` into the iOS app bundle (AirDrop or drag into Xcode)
5. iOS app displays the nudges

## Setup Instructions

### Mac (data extraction)
```bash
cd Drift
pip install -r requirements.txt
export GEMINI_API_KEY="your-key-here"
python3 extract.py
```

### iOS (app)
```
Open DriftApp/Drift.xcodeproj in Xcode
Copy nudges.json into the project
Build & Run on Simulator or device
```

## Nudge JSON Format
```json
{
  "id": "uuid-string",
  "contact_name": "Jake",
  "phone_or_email": "+1234567890",
  "days_since_contact": 67,
  "total_messages": 342,
  "drift_score": 5.1,
  "talking_points": ["Hey! How have you been?", "..."],
  "last_message_preview": "Yeah let's hang soon",
  "dismissed": false
}
```

## What Each Person Can Work On
- **Python script** (`extract.py`): iMessage reading, contact scoring, Gemini integration
- **iOS app**: SwiftUI views, data model, dismiss logic, styling
- **Algorithm**: Tuning the drift scoring formula (currently `total_messages / days_since_last_contact`)
