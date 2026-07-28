# MatchPost — Plan

What we're building and why. Read this when a decision needs revisiting.

---

## What it is

A macOS app for Troy to turn photos of his son's football matches into
Instagram posts, and to accumulate a career record of every match played.

**User:** one parent, on one Mac. Not multi-user, no accounts, no backend.
**Subject:** one player, 14, playing youth football in Eindhoven (DBS / vv Acht).
**Cadence:** roughly weekly during the season.

## Environment constraint — stated up front

The Claude container is **Linux with no Swift toolchain and no Xcode** (verified:
`swift`, `xcodebuild`, `xcrun` absent). Claude authors Swift; it can never
compile or run it. The loop is **author → Troy builds → Troy pastes errors → fix**.

This is the single biggest cost driver on the project. It is why sprints are
small, why conventions live in `CLAUDE.md`, and why "boring Swift" is a rule.

---

## The core insight

The **photos are the perishable input**. Match metadata can be back-filled
forever — scores, opponents and dates are recoverable from memory, the club, or
a calendar. But an unsorted heap of thousands of photos gets harder to
attribute every week that passes, as memory of "which match was this?" fades.

So the build order follows perishability, not feature importance:
**ingest and attribute photos first**, enrich with match data later.

This is already reflected in what works: photos dropped into the app
self-organise into match sessions by EXIF timestamp, and home/away is inferred
from GPS. That happens with no network, no API and no typing.

---

## Architecture

```
Photos (drag-drop)
   ↓  EXIFReader — date + GPS
   ↓  PhotoGrouper — 2-hour sliding window → one session per match
   ↓  HomeVenueLocator — GPS within 1 km of DBS/vv Acht → home, else away
StagedPostGroup (CoreData)  ← the posting queue, oldest match first
   ↓  match details (see "Match data" below)
   ↓  ClaudeService — bilingual caption + English hashtags
   ↓  publish (see "Publishing" below)
MatchPhoto + MatchRecord (CoreData) — the permanent career record
   ↓  HTMLProfileGenerator → thegaplab.net/players/
```

**Layering:** `Utilities/` is pure functions (no I/O, no CoreData) and carries
the tests. `Services/` owns all network I/O. `ViewModels/` are `@MainActor` and
own all `Task { }`. Views own no business logic.

## Data model

- **Player** — one row. Name, position, club, shirt number, date of birth.
- **CareerEntry** — one per club/season. Builds the career timeline.
- **StagedPhoto** — a dropped photo: asset id, EXIF date, GPS, thumbnail.
- **StagedPostGroup** — a match session. Owns 1..n StagedPhotos in posting
  order (`queuePosition`, 1…n). First photo is the carousel cover.
- **MatchRecord** — date, opponent, score, home/away, venue, competition.
- **MatchPhoto** — the permanent record of a published post.

`StagedPostGroup` → `MatchPhoto` is the staged-to-permanent transition.

---

## Match data — decided by research, not assumption

Researched 2026-07-28. **Read the confidence labels** — the container's egress
allowlist blocks every Dutch domain (`x-deny-reason: host_not_allowed`), so
nothing below was confirmed by loading the actual page. It comes from
search-index content and from third-party source code on GitHub.

**Reasonably solid:**

- Sportlink published a support article titled *"De KNVB-Dataservice stopt,
  wat nu?"* announcing the Dataservice ending **1 July 2017**, with clubs
  migrated to **Sportlink Club.Dataservice**; the commercial arm is now
  **Voetbal Data Centre**.
- Working third-party integrations call **`data.sportlink.com`** with a
  **`client_id`**, not `api.knvbdataservice.nl`. That `client_id` lives in the
  club's Sportlink Club admin panel — the club owns it, not a parent.
- **voetbal.nl has no public JSON API** — HTML only.
- **voetbal.nl's terms explicitly prohibit** "software, apparaten, scripts,
  robots … om Voetbal.nl gegevens te kopiëren of te scrapen". Enforceable
  under Dutch law. **Scraping it is out** — this is the firmest finding here.

**NOT verified — do not repeat as fact:**

- The present state of `api.knvbdataservice.nl`. It is indexed as a live
  documentation site (chapter URLs like `/hoofdstuk/wedstrijden`). Whether it
  still serves docs, and whether any key can be obtained through it, is
  **unknown from this container**. Troy can load it in a browser in ten
  seconds; that settles it.
- That voetbal.nl requires login since 2026 (single-source, a scraper README).

**Consequence for the code:**

- **`VoetbalScraper.swift` is deleted** in S1. The scraping prohibition is the
  solid finding, and that is sufficient grounds on its own.
- **`KNVBService.swift` is quarantined, not deleted**, pending Troy's check.
  Note that its current contents are wrong regardless: the `/v2/` endpoint
  shapes were written from recall, and the host is plain `http://`, which App
  Transport Security blocks. If a key does turn out to be obtainable, the file
  gets rewritten against verified endpoints rather than resurrected.

**The question that actually decides this is not "is the site up?" but "can
Troy obtain a key?"** Everything hangs on that, and it is answered by asking
the club, not by reading documentation.

**What replaces them, in order of preference:**

1. **Manual entry (baseline, always works).** Opponent + score is two fields
   and ten seconds, typed once per match while the memory is fresh. It has no
   dependencies, no credentials, and no failure mode. This is the primary path
   and it ships first.
2. **Club's own Sportlink widget (optional enhancement).** Clubs licence
   `data.sportlink.com` and publish it publicly — vv Acht already has a widget
   page at `vvacht.nl/knvb-widgets/`. Reading the club's own public page with
   the club's blessing avoids the voetbal.nl terms entirely. **Blocked on Troy
   emailing the club webmaster** for their `client_id`. Do not reuse a
   `client_id` scraped from someone's HTML — that is unauthorised use of a
   licensed service.
3. **iCal feed (fixtures only).** Voetbal.nl emails a tokenised calendar URL
   (`data.sportlink.com/ical-team?token=…`). Gives date, opponent, home/away,
   venue — **but no scores.** Useful for pre-filling everything except the
   result. Zero legal grey area.

## Publishing — open decision

**Status: unverified.** The research agent for this died on a spend limit, so
current Instagram API requirements have *not* been confirmed. Nothing should be
built on the existing `InstagramService` until they are.

Two candidate designs:

**A — Direct API publish (what exists now, unverified).** Requires: converting
the account to Business/Creator, a Meta developer app, OAuth, a public HTTPS
image URL (hence Cloudinary), and periodic token refresh. Four of the eight
credentials in Settings exist only to serve this. **Unresolved risk: the
account belongs to a minor** — Meta's policy on API publishing to a 14-year-old's
account is exactly the thing that needs verifying.

**B — Export and post from the phone (the reframe).** The app writes the
ordered images and the caption to a folder (or the clipboard) and Troy posts
from Instagram on his phone in about fifteen seconds. This **deletes three
subsystems**: `InstagramService`, `ImageHostingService` (Cloudinary), and the
OAuth flow — along with four credentials and the 60-day token-refresh chore.

**Recommendation: B**, unless Troy specifically wants hands-off automation.
The weekly cadence does not justify the setup burden or the ongoing
maintenance, and B has no dependency on Meta policy for minors. B can be built
now; A cannot be built responsibly until the research is redone.

**This needs Troy's decision before Sprint 5.**

## Captions

Claude generates a 3–4 sentence caption that is **deliberately bilingual
Dutch/English** — this is the one place Dutch is wanted. It references the
player's career history, so the caption for a match in his second season can
say something the first season's could not.

**Hashtags are English only.** Built from team, opponent, competition, age
group and score, plus a fixed English set, capped at 30.

## GAP Lab integration

`HTMLProfileGenerator` produces a static player page for
`thegaplab.net/players/`. The site is a plain static repo — the generated page
is committed alongside it. `players/` currently holds only `.gitkeep`.

Lowest priority: it depends on there being a career record worth showing, which
means it comes after matches accumulate.

---

## Decisions taken

| Decision | Reasoning |
|---|---|
| Single SwiftPM executable target | The library/extension split never compiled; SwiftPM cannot build loadable `.appex` bundles anyway. One module, no `public` churn. |
| Photos extensions not built | Same reason, plus they need the paid developer program. Sources kept as a blueprint for a future Xcode project. |
| CoreData, `codeGenerationType="none"` | Hand-written entity files are visible to Claude; generated ones are not. |
| No third-party dependencies | Nothing to resolve, nothing to break, no supply chain. |
| Keychain + `~/.matchpost/credentials` | Keys never enter the repo. File fallback avoids retyping in Settings. |
| Manual match entry as the primary path | The only route with no dependency, no credential and no failure mode. |

## Open decisions — need Troy

1. **Publishing: A or B above.** Blocks Sprint 5. Recommendation: B.
2. **Xcode project migration.** Staying on SwiftPM costs two workarounds
   already (activation policy, `Bundle.module`) and permanently rules out the
   Photos extensions. Migrating costs €99/year and a day of setup. Not urgent;
   revisit when the extensions actually matter.
3. **Club `client_id`** — one email to the DBS / vv Acht webmaster unlocks
   automated fixtures *and* results. Worth sending; costs nothing to ask.

## Non-goals

Multi-user. A backend. iOS. Video. Real-time anything. Publishing anywhere
other than Instagram and the GAP Lab page. Player recognition by face.
