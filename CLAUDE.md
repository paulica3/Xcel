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
- **No draws** (`Series.seriesResult`): a standard 7-game week always reaches 4 wins or losses, so someone wins every week. The only way a week can end level (e.g. 3-3 with nobody at 4) is an excused game from a **Timeout power-up** (a won Challenge Call now flips the L to a W, so it no longer voids a slot). Once every game is settled (`allGamesSettled`), more wins takes it; a dead-even battle resolves to a WIN for the user - the "reward the fight" ethos. There is never a displayed-as-final draw.
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
- ✅ Two-touch ritual + 5 daily notifications (morning, 11:30 lock warning, 4pm score check-up, 6pm logging-open, evening), noon edit lock. **State-aware:** the daily reminders are scheduled per-day over a 7-day horizon (not as repeating triggers) so today's are skipped once the action is done - no "log your day" nudge if the day's already logged, no "set your plan" nudge if the plan is set. Refreshed on each app open with today's state (`NotificationManager.reschedule(... skipTodayMorning:skipTodayEvening:)`, wired in `ContentView`).
- ✅ Logging window - the evening result can only be submitted between 6:00 PM and 11:59 PM local (`Game.isLoggingOpen`, `Game.loggingOpenHour`); the entry can be pre-filled earlier but not graded. Gated in `EntryView` + reflected in the `SeriesView` CTA.
- ✅ Challenge Call - one contested loss per series (NBA coach's-challenge style). User makes a case (own the mistake + a concrete fix plan); the AI judge reviews and either overturns (**flips the L into a W**, the call goes the player's way like a real NBA challenge) or denies it. One shot, win or lose, so it's not a weekly free pass. Replaced the old "Injured Reserve" free-excuse. (`ChallengeService` / `ChallengeSheet`, `Game.challenged`/`challengeOverturned`/`challengeRuling`, `Series.canChallenge`; a granted challenge sets `Game.verdict = .win`.)
- ✅ Challenge follow-through accountability - a won challenge is a promise. The **next** series, once complete, is judged (on-device AI, heuristic fallback) against the plan the user pledged; if they didn't live it out, the Challenge Call is **locked for the following series** - earn it back by actually doing what you said. (`FollowThroughService`, `Series.followUpEvaluated`/`followUpHonored`/`overturnedChallengePlan`/`isComplete`; evaluated lazily on app open in `ContentView.task`, lockout surfaced in `GameResultView`.)
- ✅ Recurring daily tasks - user sets staple tasks (e.g. "20 pushups after waking up") in Account; they auto-pre-fill every new day's morning plan and stay fully editable. (`AppSettings.recurringTasks` in UserDefaults, `RecurringTasksView`, pre-filled in `EntryView.onAppear`.)

### Premium candidates (built on `main` now, may become paid later)
- ✅ Season stats on Home (all-time record, streak, best comeback)
- ✅ Season insights / monthly "vs Life" verdict + AI pattern analysis (`InsightsService`/`InsightsView`)
- ✅ Animated verdict reveals + series clinch celebrations
- ✅ Box Score Breakdown - day scored 0-10 to **one decimal** (e.g. 9.8) on Effort / Discipline / Mood / Productivity, plus a headline overall. The judge scores strictly: a 10.0 is reserved for a flawless day and is rare. Stored as `Double` on `Game` + `JudgeResult` (`BoxScoreView`).
- ✅ Monthly awards / Awards Night - end-of-month hardware derived from real data (wins + avg box score that calendar month): **MVP** (dominant month), **MIP** (biggest jump vs last month), **DPOY** (discipline lock-in), **6MOY** (consistently beyond the plan). Read-only, can't be faked. (`AwardsService` / `AwardsView`, entry point in Account.)
- ✅ App opening scene - a grainy XCEL + "POWERED BY XTINCT AI" cold-open on every fresh launch, swipe-up (or auto) into Home. (`LaunchView`, overlaid in `ContentView`.)
- ✅ Season box-score stats - average stat line (one decimal), per-dimension form sparklines, and a "vs prior 30 days" win-rate/box comparison on `InsightsView` (`BoxScoreAverages` / `BoxScoreTrend` / `SeasonComparison`, `AverageBoxScoreView` / `BoxTrendView`)
- ✅ Game ball - user taps one morning task as the day's priority (`ChecklistItem.isGameBall`); the judge weights it heaviest (can carry a borderline day or sink it)
- ✅ Guide voices - user picks 1 of 3 guides (`Guide`: The Ant / The Maestro / The King) in Account; injected into the judge's instructions as tone only, never changing how strictly it scores. Characters *inspired by* the nicknames/personas of three all-time greats, with original non-trademark names. Optional comic-portrait assets (`guide_ant`/`guide_maestro`/`guide_king` in Assets.xcassets) show in the picker when present, with an SF Symbol fallback. (Renamed from "The Joker" to "The Maestro" to avoid the Warner/DC trademark.)
- ✅ Voice-to-text evening entry (Apple Speech, on-device; `Dictation.swift` / `MicButton`)
- ✅ End-of-week AI series recap, broadcast style (`RecapService` / `SeriesRecapCard`)
- ✅ Intention coaching - AI tightens vague morning tasks before lock-in (`CoachService` / `CoachingSheet`)
- ✅ AI plan generator - a **separate guided mode** in the morning builder: type a one-line intention, the on-device AI drafts a concrete, provable checklist (3-6 tasks), the user tweaks/deselects, and it merges into the manual plan. Heuristic split fallback when Apple Intelligence is off. (`PlanService` / `PlanSheet`, wired in `EntryView`.)
- ✅ Arena themes (cosmetics) - bundled court "looks" (Hardwood / Blacktop / Parquet / Midnight / Royal) that swap the **background** backdrop, court-line color, and optional center glow. **Light touch** (accent color stays a separate pick; layout unchanged). Theme-aware `CourtBackground` reads `AppSettings.theme`; picked in Account → Appearance with live previews. **All unlocked** in the testing build (pricing/gating deferred per build-everything-first). (`ArenaTheme` in `Theme.swift` / `AppearanceView`.)
- ✅ Share cards - branded W/L / verdict image to IG Stories, share sheet (WhatsApp/Telegram/Messages/…); `Share.swift`
- ✅ Trophy case - all-time achievement badges (`TrophyCaseView`)
- ✅ High-stakes elimination/comeback notifications, separately toggleable
- ✅ AI GM memory - the judge gets a longitudinal briefing (career record, current streak, weakest weekday, most-dropped recurring task) built from history and injected into the daily verdict as personalization (never changes scoring). Subtle "GM's read" nudge before submit. (`SeasonMemory`, wired through `JudgeService.judge(... memory:)` + `SubmitView`.)
- ✅ Road to the Finals / Rings / Dynasty - solo season arc: 4 series wins = 1 ring (Round 1 -> Conf. Semifinals -> Conf. Finals -> The Finals); rings stack into Champion/Back-to-Back/Three-peat/Dynasty. Read-only framing over series history, never alters the weekly loop. Ladder view, Home banner, trophies, ring-clinch ceremony. (`Postseason` / `RoadToFinalsView`.)
- ✅ Power-ups / Locker Room - "Momentum" currency earned from wins (derived from data, can't be faked) minus spent (persisted). Two power-ups: Timeout (excuse a past L) and Buzzer Beater (re-open a past L to replay). (`PowerUpStore` / `PowerUp` / `PowerUpsView`.)
- ✅ Photo proof - attach a done-task photo, **from the library or shot in-app** (`CameraPicker`). An in-app shot is same-day-verified by definition (most trustworthy). For library photos, the same-day check reads the **Photos asset `creationDate`** first (survives screenshots/edits/re-saves where EXIF often doesn't), falling back to EXIF/TIFF. Plus an on-device Vision label match. No network. Verified same-day proof is trusted more by the judge. (`PhotoProof` / `PhotoProofRow`, `NSCameraUsageDescription` added.)
- ✅ Intention checklist + photo proof (was "planned", now built across `PlanService`/`PlanSheet` for the AI-drafted checklist and `PhotoProof` for same-day Photos-asset/EXIF + Vision verification).

### Blocked on Apple Developer Program (own phase)
These need paid-program capabilities/entitlements (and, for widgets, a new embedded extension target) - can't be built/provisioned on a free Apple ID and shouldn't be hand-wired via CLI. Tackle once enrolled.
- **HealthKit / screen-time auto-verification** - confirm tasks (workout, sleep, screen time) from HealthKit instead of pure self-report. Needs the HealthKit entitlement + usage strings + provisioning.
- **Widgets + Live Activity** - today's scoreline on Home screen / Dynamic Island ("Game 6 tonight"). Needs a WidgetKit app-extension target + App Group entitlement (shared SwiftData/UserDefaults) + ActivityKit.

### League candidates (need accounts + backend - see "Accounts & Sync")
- **Leagues / Conferences with friends** - friends form a conference, everyone runs their own weekly series, a shared standings board shows each member's W-L for the week. This is the primary viral/growth loop and the main reason we need real accounts.
- **Head-to-head rivalry weeks** - pair two members for the week ("you vs. Marcus, both 3-2, Game 7 tonight"). Social accountability is the single biggest retention driver.
- Shared leaderboard / rivalry tracking

### Cosmetics (one-time IAP later; all unlocked in the testing build)
- ✅ Court/arena backgrounds - bundled `ArenaTheme` looks (light-touch background/line/glow swaps), see the Arena themes entry above.
- Jersey-style UI themes - deeper than the light-touch court themes (would restyle cards/components, not just the backdrop). Not built.
- Alternate broadcast skins (original, non-trademark "broadcast" aesthetics - never literal ESPN/TNT/NBA TV; name them like the guides). Deeper restyle of scoreboard/verdict reveal. Not built.

> ✅ = already built and in the testing deployment. Unchecked = not built yet.

---

## Roadmap - "Game-changing" bets (post-test-build)

These are the big swings we want after the testing build validates the core loop. They are intentionally ambitious. Most depend on **Accounts & Sync** (below) and/or the paid Apple Developer Program. Priority order is roughly top-to-bottom.

- **Leagues / Conferences with friends** - see "League candidates" above. The growth engine. Depends on accounts + backend.
- **The Finals / Playoff bracket** - after N regular-season weeks, top performers in a league enter a single-elimination bracket. Gives the whole app a *season arc* with a real ending instead of an endless treadmill. Big emotional payoff and a natural premium hook. Depends on leagues.
- **Trade deadline / Power-ups** - earn currency from wins; spend on a "timeout" (one excused make-up day) or a "buzzer beater" (re-judge one borderline L per series). Light game economy so wins accrue to something. (Injured Reserve is the seed of this.)
- **AI season-long GM with memory** - the judge currently scores per-day. Give it longitudinal memory so the *daily* verdict can reference patterns ("third Monday in a row you skipped the gym - that's your weak side"). The `InsightsService` pattern engine already half-exists; wire its findings into the daily verdict to make the judge feel scary-smart.
- **Photo / proof verification** - (also listed under premium candidates) EXIF same-day check + on-device Vision matching the photo to the stated intention. The credibility feature: turns self-report into *verified* report, which is what makes a competitive league fair. Needs PhotoKit + Vision + EXIF.
- **Dynasty mode** - track consecutive series won across weeks; a franchise/dynasty meter, banner-raising ceremony on a 3-peat. Leans all the way into the NBA franchise fantasy.
- **Widgets + Live Activity** - (blocked on Dev Program) tonight's scoreline on the Home screen / Dynamic Island ("Game 6 tonight - 3-2"). Major re-open driver. Needs a WidgetKit extension target + App Group + ActivityKit.
- **Apple Watch companion** - quick "log the day" + a complication showing tonight's game. Watch presence meaningfully lifts daily-ritual compliance. Needs a watchOS target.
- **HealthKit auto-verification** - (also listed under blocked-on-Dev-Program) a "workout" task auto-confirms from a logged Apple Watch workout. Removes friction *and* fights cheating. Needs the HealthKit entitlement.

### Recommended priority stack
1. **Accounts & Sync (Option B)** - the prerequisite for everything social.
2. **Leagues + rivalry weeks** - the growth engine.
3. **Season arc / Finals bracket + Dynasty mode** - retention + emotional payoff.
4. **Widgets + Live Activity + Apple Watch** - once enrolled in the Dev Program.
5. **Photo proof + HealthKit verification** - credibility layer that makes leagues fair.

---

## Accounts & Sync

**Decision (locked):** cross-device data uses **real accounts + our own backend (Option B)**, NOT CloudKit private sync. Reason: the headline roadmap features (leagues, rivalry weeks, shared leaderboards, brackets) require users to see *each other's* data, which CloudKit's per-Apple-ID private database can't do. We go straight to the architecture the social features need rather than migrating twice.

- **Auth:** Sign in with Apple as the primary (and initially only) provider. Apple requires it whenever any third-party login is offered, and it gives us a stable user ID with minimal PII. Email/Google can come later.
- **Backend:** Supabase is the current pick (managed Postgres + auth + realtime + row-level security, generous free tier, SQL we control). Firebase is the fallback. Avoid rolling our own server.
- **Local-first stays:** SwiftData remains the on-device source of truth so the app works offline and the daily ritual never blocks on network. The backend is a **sync layer on top**, not a replacement. Entries are judged on-device (Apple Intelligence) and then pushed; never gate journaling on connectivity.
- **What syncs:** series, games, verdicts, box scores, settings (the user's own data) + league membership and other members' *summary* standings (W-L), not their raw journal text. Raw entries stay private to the author.
- **Prerequisite:** paid Apple Developer Program (Sign in with Apple entitlement) + a privacy policy (we now collect/store user data off-device).

> Implementation note: build this behind a `SyncService` protocol the same way the judge is abstracted, so the local-only build keeps working and the backend can be swapped/mocked. No view should talk to Supabase directly.

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
