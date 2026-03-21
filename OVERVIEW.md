# Drift — Project Overview

> Never lose touch with the people who matter.
> A friendship-maintenance app for macOS and iPhone.

---

## What is Drift?

Drift is a two-part app that reads your iMessage history, identifies friends you're losing touch with, and nudges you to reach out — complete with AI-generated talking points. It runs a **macOS menu bar companion** that syncs your data, paired with an **iOS app** where you act on nudges.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        macOS Menu Bar App                        │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │  Read chat.db │───▶│ Score Contacts│───▶│ Gemini API Call  │  │
│  │  (SQLite)     │    │ (Drift Score) │    │ (Talking Points) │  │
│  └──────────────┘    └──────────────┘    └───────┬───────────┘  │
│                                                   │              │
│                                          ┌────────▼────────┐    │
│                                          │    Firestore     │    │
│                                          └────────┬────────┘    │
└───────────────────────────────────────────────────┼──────────────┘
                                                    │
                                          (Real-time sync)
                                                    │
┌───────────────────────────────────────────────────▼──────────────┐
│                          iOS App (SwiftUI)                        │
│  ┌──────────────┐    ┌──────────────────┐   ┌────────────────┐  │
│  │ Nudge List   │───▶│  Nudge Detail     │──▶│ Send / Keep /  │  │
│  │ (Cards)      │    │  (Talking Points) │   │ Remove         │  │
│  └──────────────┘    └──────────────────┘   └────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

### macOS — Data Extraction & Menu Bar

| Component        | Technology                     | Notes                                                        |
| ---------------- | ------------------------------ | ------------------------------------------------------------ |
| Language         | **Python 3.10+**               | Fast to write, great library support                         |
| iMessage access  | **sqlite3** (stdlib)           | Reads `~/Library/Messages/chat.db`                           |
| AI               | **Google Gemini API**          | `google-generativeai` package — generates talking points     |
| Sync             | **Firebase Firestore**         | `firebase-admin` — writes nudge documents to cloud           |
| Menu bar UI      | **macOS Popover** (SwiftUI)    | Lightweight status-bar companion with sync status            |

### iOS — User-Facing App

| Component   | Technology                   | Notes                                          |
| ----------- | ---------------------------- | ---------------------------------------------- |
| Framework   | **SwiftUI**                  | Declarative UI, modern Apple development        |
| Min target  | **iOS 17**                   | Latest SwiftUI features                         |
| Sync        | **Firebase Firestore** (SPM) | Real-time listener for nudge updates            |
| Messaging   | **URL scheme (`sms:`)**      | Opens iMessage to a contact directly            |

---

## APIs

### Google Gemini API

- **Purpose:** Generate personalized talking points based on message history with a contact
- **Package:** `google-generativeai`
- **Auth:** API key (set via `GEMINI_API_KEY` env variable)
- **Get a key:** [Google AI Studio](https://makersuite.google.com/app/apikey)
- **Usage:** Send recent message context for a drifting contact → receive suggested conversation starters

### Firebase Firestore

- **Purpose:** Real-time sync of nudge data between Mac and iOS
- **Mac side:** `firebase-admin` — Python writes nudge documents
- **iOS side:** `FirebaseFirestore` via SPM — real-time listener updates UI automatically
- **Setup:** Firebase Console → Create project → Add Firestore database (test mode)

### iMessage Database (Local)

- **Path:** `~/Library/Messages/chat.db`
- **Type:** SQLite database
- **Access:** Requires Full Disk Access granted to Terminal (System Settings → Privacy & Security → Full Disk Access)
- **Apple epoch offset:** `+978307200` to convert timestamps to Unix time

---

## UI/UX Design

### macOS — Menu Bar Popover

A minimal menu bar popover that sits in the macOS status bar.

**Components:**
- **Status indicator** — green dot when synced
- **Title** — "Drift"
- **Close button** (×)
- **Sync status** — "Last synced X min ago"
- **Settings** button — opens preferences
- **Quit** button — exits the app

**Sync states:**
| State     | Appearance                     |
| --------- | ------------------------------ |
| Synced    | Green pill badge               |
| Syncing   | Neutral/gray pill badge        |
| Error     | Red outline pill badge         |

### iOS — Nudge Interface

**Screen 1: Nudge List**
- Card-based layout showing friends you're drifting from
- Each card shows: contact name, days since last contact, drift score
- Sorted by drift score (highest urgency first)

**Screen 2: Nudge Detail**
- Contact info and drift score
- AI-generated talking points as tappable suggestions
- Action buttons:
  - **Send** — opens iMessage via `sms:` URL scheme
  - **Keep** — saves the nudge for later
  - **Remove** — dismisses the nudge

---

## Data Model

### Firestore Collection: `nudges`

```json
{
  "id": "auto-generated",
  "contact_name": "Jake",
  "phone_or_email": "+1234567890",
  "days_since_contact": 67,
  "total_messages": 342,
  "drift_score": 5.1,
  "talking_points": [
    "Hey! How's the new job going?",
    "We should grab coffee soon"
  ],
  "last_message_preview": "Yeah let's hang soon",
  "dismissed": false,
  "created_at": "timestamp"
}
```

### Drift Score

- **Formula (v1):** `total_messages / days_since_last_contact`
- Higher score = stronger friendship drifting away = higher urgency
- Algorithm is pluggable — designed to be tuned and swapped easily

---

## Data Flow

1. Run the Python extraction script on Mac (requires Full Disk Access)
2. Script reads iMessage database and scores all contacts
3. Gemini API generates talking points for top drifting contacts
4. Script writes nudge documents to Firestore
5. iOS app listens to Firestore in real-time → UI updates automatically
6. User taps Keep/Remove → updates Firestore document

---

## Setup

### 1. Firebase Project (one-time)
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

---

## Key Files

| File                          | Description                                              |
| ----------------------------- | -------------------------------------------------------- |
| `extract.py`                  | Main Python script — reads iMessage, calls Gemini, writes to Firestore |
| `requirements.txt`            | Python dependencies                                      |
| `serviceAccountKey.json`      | Firebase credentials (**DO NOT COMMIT**)                 |
| `GoogleService-Info.plist`    | Firebase iOS config                                      |
| `DriftApp/`                   | iOS SwiftUI project                                      |
| `TECHSTACK.md`                | Detailed tech stack breakdown                            |

---

## Work Breakdown

| Area              | Scope                                                      |
| ----------------- | ---------------------------------------------------------- |
| Python script     | iMessage reading, contact scoring, Gemini integration, Firestore writes |
| iOS app           | SwiftUI views, Firestore listener, dismiss logic, styling  |
| macOS menu bar    | Popover UI, sync status, settings                          |
| Algorithm         | Tuning the drift scoring formula                           |
| Firebase          | Project setup, security rules, schema                      |
