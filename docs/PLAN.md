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

Researched 2026-08-17. **Read the confidence labels** — the container's egress
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

**Verified by Troy loading the docs, 2026-08-17 — this supersedes the above:**

`api.knvbdataservice.nl` is **live**, serving the *Voetbal Datacentre API*
documentation. An earlier claim in this file that it was dead was wrong: what
was true is only that this container cannot reach it.

- **Real API host: `https://api.voetbaldatacentre.nl/api/`** — HTTPS. The
  `http://api.knvbdataservice.nl/v2/` base in `KNVBService.swift` was invented
  from recall and is wrong on both host and path. HTTPS also removes the App
  Transport Security problem.
- **Auth is two-step, not a bearer key.** Every call carries `PHPSESSID`
  (obtained from an initialisation call) plus `hash` (computed client-side).
  The docs state plainly: *"U heeft een API sleutel nodig."*
- **`GET /api/wedstrijden`** returns a match listing **for the whole club**, so
  youth teams are included. Optional params: `weeknummer` (1–52, or `A` for
  everything), `zaalveld`, `comptype` (`R` regular / `B` cup / `N` play-off /
  `V` friendly), `order=time`.
- **The output carries everything `MatchRecord` needs:** `Datum`, `Tijd`,
  `ThuisClub` / `UitClub`, `ThuisTeamId` / `UitTeamId`, `PuntenTeam1` /
  `PuntenTeam2`, plus extra-time and penalty variants, `Competitie`,
  `District`, `MatchID`, `WedstrijdNummer`, and full venue address
  (`Facility_naam`, `_Stad`, `_Postcode`, `_Adres`).

**What this changes:**

- **Home/away becomes exact.** Comparing his team against `ThuisTeamId` /
  `UitTeamId` beats inferring from GPS radius. `HomeVenueLocator` stays as the
  fallback for when no match record is available, not as the primary signal.
- **Almost all manual entry disappears** where a key exists — opponent, score,
  competition, venue and date all arrive from one call.
- **`KNVBService.swift` is rewritten, not revived.** Correct host, HTTPS, the
  `PHPSESSID` + `hash` flow, and `/api/wedstrijden` decoding.

**Still open — the one thing that gates it:** whether Troy can obtain a key as
an individual, or only through DBS / vv Acht's club account. The `client_id`
evidence from third-party integrations suggests club-mediated, but the docs
site being public and live means a direct route may exist. **Ask the club
regardless** — it costs one email and unlocks the whole path.

**`VoetbalScraper.swift` is quarantined, not deleted.** voetbal.nl's terms
prohibit scripts and robots, and the sanctioned API supersedes it — but
"superseded" only counts once the replacement works, and S7 is gated on a key
we do not have. Nothing is removed from this repo until the thing replacing it
runs. An unwired file costs nothing to keep.

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
3. **iCal feed — the answer to "where do I download the matches" today.**
   Voetbal.nl emails a tokenised calendar URL on request:
   `data.sportlink.com/ical-team?token=…` (team) or `…/data/ical-person?token=…`
   (one player's programme). Sanctioned, stable, no key negotiation, no scraping.

   Gives date, time, opponent, home/away and venue. **Believed not to carry
   final scores** — flagged as unverified by the research, and settled the
   moment Troy subscribes and looks at an event.

   This is a good trade: it supplies every field that is tedious to type, and
   withholds only the score — the one fact a parent who attended the match
   always knows. Import the fixture, type `3–1`, done.

## Publishing — decided: Instagram API

**Decision (Troy, 2026-08-17): publish directly via the Instagram API.** He has
a Business account. `InstagramService` and `ImageHostingService` therefore stay;
the "export and post from the phone" alternative is dropped.

### Image hosting — iCloud is ruled out, verified

Meta's servers **fetch the image URL server-side with cURL**, so the URL must be
publicly reachable, require no authentication, and return **raw image bytes with
a correct Content-Type**. It must not redirect to an HTML page.

**iCloud does not work, and neither do Google Drive, Dropbox, OneDrive or
SharePoint** — Meta names them explicitly. They all serve an HTML preview or
download page rather than the file itself. So an Apple shared folder is not an
option, and this is settled rather than a matter of configuration.
Source: [Meta — Publish Content using the Instagram Platform](https://developers.facebook.com/docs/instagram-platform/content-publishing/)

**Hosting stays Cloudinary** (already built, free tier, unsigned upload, no
server). The deciding argument is that the hosting need is **transient** — Meta
fetches the image once while creating the container, after which the URL can
die. Cloudinary lets an image be deleted afterwards.

*Considered and rejected: publishing images through the GAP Lab site's own
GitHub Pages (`thegaplab.net`), which Troy already owns. It would work, but git
history is permanent — photos of a minor would remain public and recoverable
forever even after "deletion", which is a materially different privacy posture
from Instagram, where a post can actually be removed. Also adds a 30–60s deploy
wait before the URL is live.*

### Media constraints that affect our code

- **JPEG only.** PNG, WebP, GIF rejected. `ImageResizer` already outputs JPEG.
- **Aspect ratio must be between 4:5 (0.8) and 1.91:1.** `ImageResizer`
  currently **preserves the source ratio**, so a portrait phone photo at 3:4
  (0.75) — or anything shot 9:16 — would be **rejected on first post**. This is
  a live bug, fixed in S5.
- **Carousels take their ratio from the first image**, so a group mixing
  portrait and landscape needs one normalisation decision applied to all.

### Whose account — settled

**Troy's own Business account** (confirmed 2026-08-17). The earlier concern
about Meta's policy on API publishing to a minor's account **does not apply**
and is closed. No account conversion is needed for his son, and nothing about
the publishing path depends on the son having an Instagram presence at all.

**Consequence for caption voice:** posts come from a parent's account about
his son, so captions must read in **a parent's voice** — proud third person,
not the player's first person. The current `generateCareerCaption` prompt says
only "reference the player's journey", which is ambiguous enough to produce
"Wat een wedstrijd! I scored twice" — wrong, and wrong in a way that would only
be noticed after posting. Pinned down in S3.

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
