# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Xcel** (pronounced "excel") - an iOS journaling app that gamifies your week using the NBA playoff 7-game series format. Each week is a series, each day is a game. You journal how the day went, and an AI judge issues a Win or Loss verdict. Comeback narratives (down 1-3, win 4-3) are a core emotional mechanic.

---

## Platform & Stack

- **Framework:** SwiftUI (iOS only)
- **Target:** iPhone (developer device: iPhone 17 Pro)
- **Storage:** SwiftData, local-only (no iCloud sync to start). Store both the raw entry text and the structured AI output (verdict, one-liner, scores) so future features like recap and search work without a re-call.
- **AI:** Claude API - called once per journal entry on manual submission
- **Purchases:** StoreKit 2 for subscriptions and one-time IAP
- **Voice:** Apple Speech framework (on-device transcription before AI call)

---

## Branch Strategy

**Current phase - build-everything-first (testing deployment).** We are NOT splitting free vs premium yet. The goal is one complete, polished testing build that contains *all* the features - free, premium-candidate, everything - so we can put it in front of testers and feel out what actually lands. Tier decisions come *after* the test build, based on what testers value.

| Branch | Purpose |
|---|---|
| `main` | The testing deployment. Build all features here - daily entry, AI verdict, scoreline, history, season stats/insights, notifications, etc. Keep it clean and shippable to TestFlight, but it is NOT limited to the free tier. |
| `premium` | Reserved for later. Once we know which features deserve to be paid, the monetization split happens here. Not in active use during the build-everything phase. |

**How we decide tiers (later):** ship the full testing build → gather tester feedback on which features they'd pay for / which are "wow" moments → only then carve the paywalled set into `premium` and trim `main` to the free tier.

**Critical constraint (still holds):** Keep clean separation of concerns so the eventual free/premium carve-up is a configuration/packaging change, not a refactor. No feature should be so tangled into core logic that it can't be gated or moved later. Build premium-candidate features behind clear boundaries (own files/services) even while everything lives on `main`.

---

## Core Mechanics

- 1 series = 1 week (7 games)
- 1 game = 1 day
- Series runs Monday–Sunday, fixed calendar week
- User taps "Submit day", sees a confirmation screen, then the AI judge fires → Win or Loss returned
- Once judged, the day is locked - no edits or resubmissions
- Missing a day = automatic Loss (no excuses, high stakes)
- Series scoreline displayed at all times (e.g. "3-2 - Game 6 tonight")
- A loss is framed within the series context, never as a standalone life judgment
- First team to 4 wins takes the series
- **Dynamic difficulty** (`JudgeStance` in JudgeService): down 2+ games triggers "Home Court Advantage" (judge eases up, honest effort earns a W); 3-0 lead triggers "Raise the Bar" (judge gets stricter). Goal: users win more often than not, but a runaway lead gets challenged.

---

## App Structure & Navigation

- **Home is a landing page**, not the game. Users do NOT jump straight into the series. Home → "Enter the arena" → `SeriesView` (scoreboard).
- `Theme.swift` - `AppSettings` (`@Observable`, injected via `.environment`, persisted to UserDefaults) holds the user's accent color + name. `AccentTheme` enum = 8 neon colors (green, orange, blue, pink, purple, cyan, red, gold). All views read `settings.accent.color`; never hardcode the accent.
- `BrandingViews.swift` - `WavingTitle` (accent sweeps across the wordmark) and `XtinctBadge` ("POWERED BY XTINCT AI" with subtle chaotic jitter). **XTINCT AI is the company building the app** - keep the attribution.
- `AccountView` is functional: name, accent color picker, **guide voice picker** (`Guide`), profile photo, adjustable reminder times, a high-stakes-alerts toggle, and entry points to **Season insights** (`InsightsView`) and the **Trophy case** (`TrophyCaseView`). "Go Premium" remains a placeholder row.

---

## Feature Tiers

These are **tier *candidates*, not a committed split.** During the build-everything-first phase, all of these are built on `main` for the testing deployment. The free/premium/league grouping below is our current *hypothesis* for how it might monetize - revisit it after tester feedback, not before.

### Core loop (almost certainly free)
- ✅ Daily checklist journal entry (morning plan + evening proof)
- ✅ AI Win/Loss verdict with a one-liner + coach's notes
- ✅ Weekly series scoreline + basic series history
- ✅ Two-touch ritual + 4 daily notifications (morning, 11:30 lock warning, 4pm score check-up, evening), noon edit lock
- ✅ Injured Reserve - one excused loss per series (`Game.excused`, `Series.canUseInjuredReserve`)

### Premium candidates (built on `main` now, may become paid later)
- ✅ Season stats on Home (all-time record, streak, best comeback)
- ✅ Season insights / monthly "vs Life" verdict + AI pattern analysis (`InsightsService`/`InsightsView`)
- ✅ Animated verdict reveals + series clinch celebrations
- ✅ Box Score Breakdown - day scored 0-10 on Effort / Discipline / Mood / Productivity (`BoxScoreView`, scores on `Game` + `JudgeResult`)
- ✅ Season box-score stats - average stat line (one decimal), per-dimension form sparklines, and a "vs prior 30 days" win-rate/box comparison on `InsightsView` (`BoxScoreAverages` / `BoxScoreTrend` / `SeasonComparison`, `AverageBoxScoreView` / `BoxTrendView`)
- ✅ Game ball - user taps one morning task as the day's priority (`ChecklistItem.isGameBall`); the judge weights it heaviest (can carry a borderline day or sink it)
- ✅ Guide voices - user picks 1 of 3 guides (`Guide`: The Ant / The Joker / The King) in Account; injected into the judge's instructions as tone only, never changing how strictly it scores. Characters *inspired by* the nicknames of three all-time greats. Optional comic-portrait assets (`guide_ant`/`guide_joker`/`guide_king` in Assets.xcassets) show in the picker when present, with an SF Symbol fallback. NOTE: "The Joker" is a registered Warner/DC trademark - revisit before any public App Store release.
- ✅ Voice-to-text evening entry (Apple Speech, on-device; `Dictation.swift` / `MicButton`)
- ✅ End-of-week AI series recap, broadcast style (`RecapService` / `SeriesRecapCard`)
- ✅ Intention coaching - AI tightens vague morning tasks before lock-in (`CoachService` / `CoachingSheet`)
- ✅ Share cards - branded W/L / verdict image to IG Stories, share sheet (WhatsApp/Telegram/Messages/…); `Share.swift`
- ✅ Trophy case - all-time achievement badges (`TrophyCaseView`)
- ✅ High-stakes elimination/comeback notifications, separately toggleable
- **Intention checklist + photo proof** (planned): AI turns the morning intention into a checklist; user checks off items and attaches a Photos-library image. App reads the photo's EXIF date to confirm it's same-day, and uses on-device Vision/AI to check the image matches the intention. Needs PhotoKit + Vision + EXIF - substantial; design as its own phase.

### Blocked on Apple Developer Program (own phase)
These need paid-program capabilities/entitlements (and, for widgets, a new embedded extension target) - can't be built/provisioned on a free Apple ID and shouldn't be hand-wired via CLI. Tackle once enrolled.
- **HealthKit / screen-time auto-verification** - confirm tasks (workout, sleep, screen time) from HealthKit instead of pure self-report. Needs the HealthKit entitlement + usage strings + provisioning.
- **Widgets + Live Activity** - today's scoreline on Home screen / Dynamic Island ("Game 6 tonight"). Needs a WidgetKit app-extension target + App Group entitlement (shared SwiftData/UserDefaults) + ActivityKit.

### League candidates
- Conferences with friends
- Shared leaderboard / rivalry tracking

### Cosmetics (one-time IAP)
- Jersey-style UI themes
- Court/arena backgrounds
- Alternate broadcast skins (ESPN vs TNT vs NBA TV aesthetic)

> ✅ = already built and in the testing deployment. Unchecked = not built yet.

---

## AI Judge Design

- Tough-but-fair - penalizes vague entries and excuses, rewards honesty
- Always contextualizes verdict within the series: *"You're down 2-3. This is an elimination game tomorrow."*
- Never frames a loss as a standalone life judgment
- Comeback arc (1-3 → 4-3) must feel like the best feature in the app
- Premium: different prompt personas per commentator personality

---

## Aesthetic Direction

- Color palette: black + neon green (near-black background, neon green accent `#39FF14` or similar)
- Typography: SF Pro with heavy/black weights - no custom font to start; use SF Pro Condensed where impact is needed
- Transitions feel like live TV cuts - snappy, dramatic
- Sound design: crowd noise on W, silence/buzzer on L
- The app should feel like *watching yourself compete*, not writing a diary

## Notifications & Onboarding

- Morning notification: set your intention for the day (brief free-text prompt, not judged by AI)
- Evening notification: log how the day went (default 9pm, user-adjustable) - this is what the AI judges
- Two-touch daily ritual: intention in the morning, verdict at night
- Onboarding: 3-screen explainer covering the series format, the AI judge, and what W/L means - then straight into the app

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
| Day locking | Locked after verdict | No take-backs - keeps integrity |
| Missed day | Automatic Loss | High stakes, no excuses |
| Series cadence | Monday–Sunday fixed | Predictable, aligns with real NBA week |
| Color palette | Black + neon green | High energy, arena-at-night feel |
| Typography | SF Pro heavy/black weights | Native, zero setup, still punchy |
| Home screen widget | Out of scope for now | Revisit after core app ships |
| Push notifications | Yes - daily reminder, default 9pm | Core engagement loop |
| Morning prompt | Yes - morning intention + evening entry | Two-touch ritual: set intention AM, get judged PM |
| Onboarding | 3-screen explainer | Explains format without over-engineering |

---

## Distribution Path

- **Personal use:** Free Apple ID + Xcode (7-day cert re-sign) or AltStore/Sideloadly
- **Friends:** $99/yr Apple Developer Program → TestFlight (up to 100 testers, no App Store review)
- **Public/monetized:** Full App Store submission + privacy policy required before any IAP/subscription features ship
