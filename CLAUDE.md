# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Xcel** (pronounced "excel") — an iOS journaling app that gamifies your week using the NBA playoff 7-game series format. Each week is a series, each day is a game. You journal how the day went, and an AI judge issues a Win or Loss verdict. Comeback narratives (down 1-3, win 4-3) are a core emotional mechanic.

---

## Platform & Stack

- **Framework:** SwiftUI (iOS only)
- **Target:** iPhone (developer device: iPhone 17 Pro)
- **Storage:** SwiftData, local-only (no iCloud sync to start). Store both the raw entry text and the structured AI output (verdict, one-liner, scores) so future features like recap and search work without a re-call.
- **AI:** Claude API — called once per journal entry on manual submission
- **Purchases:** StoreKit 2 for subscriptions and one-time IAP
- **Voice:** Apple Speech framework (on-device transcription before AI call)

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Free tier only — daily entry, AI W/L verdict, series scoreline, basic history. Must be clean and shippable. |
| `premium` | Paid features layered on top: box score breakdown, voice-to-text, commentator personalities, season stats, career page, weekly recap, social league, cosmetics/IAP. |

**Critical constraint:** The `main` branch architecture must support premium features being added later without refactoring core logic. Clean separation of concerns from day one — no tightly coupled free/premium paths.

---

## Core Mechanics

- 1 series = 1 week (7 games)
- 1 game = 1 day
- Series runs Monday–Sunday, fixed calendar week
- User taps "Submit day", sees a confirmation screen, then the AI judge fires → Win or Loss returned
- Once judged, the day is locked — no edits or resubmissions
- Missing a day = automatic Loss (no excuses, high stakes)
- Series scoreline displayed at all times (e.g. "3-2 — Game 6 tonight")
- A loss is framed within the series context, never as a standalone life judgment
- First team to 4 wins takes the series
- **Dynamic difficulty** (`JudgeStance` in JudgeService): down 2+ games triggers "Home Court Advantage" (judge eases up, honest effort earns a W); 3-0 lead triggers "Raise the Bar" (judge gets stricter). Goal: users win more often than not, but a runaway lead gets challenged.

---

## App Structure & Navigation

- **Home is a landing page**, not the game. Users do NOT jump straight into the series. Home → "Enter the arena" → `SeriesView` (scoreboard).
- `Theme.swift` — `AppSettings` (`@Observable`, injected via `.environment`, persisted to UserDefaults) holds the user's accent color + name. `AccentTheme` enum = 8 neon colors (green, orange, blue, pink, purple, cyan, red, gold). All views read `settings.accent.color`; never hardcode the accent.
- `BrandingViews.swift` — `WavingTitle` (accent sweeps across the wordmark) and `XtinctBadge` ("POWERED BY XTINCT AI" with subtle chaotic jitter). **XTINCT AI is the company building the app** — keep the attribution.
- Account + name + color picker live in `AccountView` (functional); notifications/photo/premium are placeholder rows.

---

## Feature Tiers

### Free (on `main`)
- Daily text journal entry
- AI Win/Loss verdict with a short one-liner
- Weekly series scoreline
- Basic series history

### Premium (on `premium`)
- Box Score Breakdown — day scored across Effort, Discipline, Mood, Productivity
- Voice-to-text entry (Speech → AI)
- AI Commentator Personalities: Hype-man, Brutal Analyst, Calm Vet Coach
- Season stats & Career page (all-time record, streaks, best comeback)
- End-of-week AI recap (optionally read aloud in broadcast style)
- **Intention checklist + photo proof** (planned): AI turns the morning intention into a checklist; user checks off items and attaches a Photos-library image. App reads the photo's EXIF date to confirm it's same-day, and uses on-device Vision/AI to check the image matches the intention. Needs PhotoKit + Vision + EXIF — substantial; design as its own phase.

### League (add-on or higher tier)
- Conferences with friends
- Shared leaderboard / rivalry tracking

### Cosmetics (one-time IAP, available to all tiers)
- Jersey-style UI themes
- Court/arena backgrounds
- Alternate broadcast skins (ESPN vs TNT vs NBA TV aesthetic)

---

## AI Judge Design

- Tough-but-fair — penalizes vague entries and excuses, rewards honesty
- Always contextualizes verdict within the series: *"You're down 2-3. This is an elimination game tomorrow."*
- Never frames a loss as a standalone life judgment
- Comeback arc (1-3 → 4-3) must feel like the best feature in the app
- Premium: different prompt personas per commentator personality

---

## Aesthetic Direction

- Color palette: black + neon green (near-black background, neon green accent `#39FF14` or similar)
- Typography: SF Pro with heavy/black weights — no custom font to start; use SF Pro Condensed where impact is needed
- Transitions feel like live TV cuts — snappy, dramatic
- Sound design: crowd noise on W, silence/buzzer on L
- The app should feel like *watching yourself compete*, not writing a diary

## Notifications & Onboarding

- Morning notification: set your intention for the day (brief free-text prompt, not judged by AI)
- Evening notification: log how the day went (default 9pm, user-adjustable) — this is what the AI judges
- Two-touch daily ritual: intention in the morning, verdict at night
- Onboarding: 3-screen explainer covering the series format, the AI judge, and what W/L means — then straight into the app

---

## Decisions Log

All architecture decisions have been locked in. Do not re-open these without the developer's input:

| Decision | Choice | Rationale |
|---|---|---|
| Storage | SwiftData, local-only | Fastest path to ship; no auth complexity |
| iCloud sync | Not now | Add after core loop is proven |
| AI model | Apple Intelligence (FoundationModels framework) | Zero cost, on-device, no network required, works offline; iOS 26 API supports system prompts + structured output. Design behind a protocol so Claude API can be swapped in later with no structural refactor. |
| Entry storage | Full text + structured output | Enables recap, search, future features |
| Judge trigger | "Submit day" button + confirmation screen | Deliberate ritual reinforces stakes |
| Day locking | Locked after verdict | No take-backs — keeps integrity |
| Missed day | Automatic Loss | High stakes, no excuses |
| Series cadence | Monday–Sunday fixed | Predictable, aligns with real NBA week |
| Color palette | Black + neon green | High energy, arena-at-night feel |
| Typography | SF Pro heavy/black weights | Native, zero setup, still punchy |
| Home screen widget | Out of scope for now | Revisit after core app ships |
| Push notifications | Yes — daily reminder, default 9pm | Core engagement loop |
| Morning prompt | Yes — morning intention + evening entry | Two-touch ritual: set intention AM, get judged PM |
| Onboarding | 3-screen explainer | Explains format without over-engineering |

---

## Distribution Path

- **Personal use:** Free Apple ID + Xcode (7-day cert re-sign) or AltStore/Sideloadly
- **Friends:** $99/yr Apple Developer Program → TestFlight (up to 100 testers, no App Store review)
- **Public/monetized:** Full App Store submission + privacy policy required before any IAP/subscription features ship
