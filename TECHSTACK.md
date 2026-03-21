# Drift - Tech Stack

## What We're Building
A Mac + iOS app that reads your iMessage history, identifies friends you're drifting from, and nudges you to reach out with AI-generated talking points.

## Architecture

```
Mac (Python script)                         iOS (SwiftUI app)
┌─────────────────────┐                    ┌─────────────────────┐
│ Read chat.db        │                    │ Nudge List Screen   │
│ Score contacts      │──▶ Firestore ──▶   │ Nudge Detail Screen │
│ Call Gemini API     │                    │ Keep / Remove / Send│
└─────────────────────┘                    └─────────────────────┘
```

## Mac Side — Data Extraction

| Component | Tech | Why |
|-----------|------|-----|
| Language | **Python 3** | Fast to write, great library support |
| iMessage access | **sqlite3** (stdlib) | chat.db is a SQLite database at `~/Library/Messages/chat.db` |
| AI | **Google Gemini API** (`google-generativeai`) | Generates talking points from message history |
| Sync | **Firebase Firestore** (`firebase-admin`) | Writes nudge documents to cloud |

### Requirements
- macOS with Full Disk Access granted to Terminal (System Settings → Privacy & Security → Full Disk Access)
- Python 3.10+
- Gemini API key (https://makersuite.google.com/app/apikey)
- Firebase service account key (from Firebase Console → Project Settings → Service Accounts)

### Key files
- `extract.py` — reads iMessage db, scores contacts, calls Gemini, writes to Firestore
- `requirements.txt` — Python dependencies
- `serviceAccountKey.json` — Firebase credentials (**DO NOT COMMIT**)

## iOS Side — User-Facing App

| Component | Tech | Why |
|-----------|------|-----|
| Framework | **SwiftUI** | Modern, declarative, fast to build |
| Min target | **iOS 17** | Latest SwiftUI features |
| Sync | **Firebase Firestore** (`FirebaseFirestore` SPM) | Real-time listener for nudge updates |
| Messaging | **URL scheme (`sms:`)** | Opens iMessage to a contact directly |

### Key screens
1. **Nudge List** — cards showing friends to reach out to
2. **Nudge Detail** — talking points + keep/remove/send buttons

## Data Flow

1. Run `python3 extract.py` on Mac (needs Full Disk Access)
2. Script reads iMessage database, scores contacts, calls Gemini
3. Writes nudge documents to Firestore
4. iOS app listens to Firestore in real-time → updates UI automatically
5. User taps Keep/Remove → updates Firestore document

## Setup Instructions

### 1. Firebase Project (one-time, ~5 min)
1. Go to https://console.firebase.google.com
2. Create new project called "Drift"
3. Add a Firestore database (start in test mode)
4. Go to Project Settings → Service Accounts → Generate new private key
5. Save as `serviceAccountKey.json` in the Drift folder
6. Add an iOS app in Firebase Console, download `GoogleService-Info.plist`

### 2. Mac (data extraction)
```bash
cd Drift
pip install -r requirements.txt
export GEMINI_API_KEY="your-key-here"
python3 extract.py
```

### 3. iOS (app)
```
Open DriftApp/Drift.xcodeproj in Xcode
Add GoogleService-Info.plist to the project
Build & Run on Simulator or device
```

## Firestore Schema

### Collection: `nudges`
```json
{
  "id": "auto-generated",
  "contact_name": "Jake",
  "phone_or_email": "+1234567890",
  "days_since_contact": 67,
  "total_messages": 342,
  "drift_score": 5.1,
  "talking_points": ["Hey! How have you been?", "..."],
  "last_message_preview": "Yeah let's hang soon",
  "dismissed": false,
  "created_at": "timestamp"
}
```

## What Each Person Can Work On
- **Python script** (`extract.py`): iMessage reading, contact scoring, Gemini integration, Firestore writes
- **iOS app**: SwiftUI views, Firestore listener, dismiss logic, styling
- **Algorithm**: Tuning the drift scoring formula
- **Firebase**: Setting up the project, security rules, schema
