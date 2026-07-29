# MatchPost — State

Where we are right now. Read at the start of every session. Keep under a page.

**Updated:** 2026-07-28 · **Branch:** `claude/soccer-match-instagram-app-bPEYF`

---

## Last session

Adopted the working method. Wrote `CLAUDE.md`, `docs/PLAN.md`, `docs/SPRINTS.md`
and this file. **No application code changed.**

Two research findings landed, and one research task died:

- **KNVB data: settled, and better than expected.** Troy loaded the docs: the
  **Voetbal Datacentre API is live** at `https://api.voetbaldatacentre.nl/api/`,
  and `GET /api/wedstrijden` returns date, both clubs, team IDs, score, extra
  time, penalties, competition and full venue address — an entire `MatchRecord`
  from one call, with **exact** home/away rather than GPS inference. My earlier
  claim that it was dead was wrong; what was true is that this container cannot
  reach any Dutch domain. `KNVBService.swift` gets **rewritten** in S7 (its
  host, path and auth were all invented from recall). `VoetbalScraper.swift` is
  still deleted in S1 — the scraping prohibition is unaffected, and with a real
  API there is no reason for it. **Gate: obtaining an API key.**
- **Instagram requirements: NOT verified.** That agent died on an org spend
  limit. Nothing may be built on `InstagramService` until it is re-run —
  including the open question of Meta's policy on API publishing to a **minor's**
  account.

## Build status

App **compiles and launches** on Troy's Mac. Getting there took four rounds of
pasted errors, since nothing can be compiled in the container.

**Nothing beyond launch has ever been exercised. No network call in this project
has ever succeeded.**

Fixed along the way: single-target restructure, `Bundle.module` CoreData model
loading, `SecureRow` initialiser, activation policy for keyboard focus.

**Unconfirmed:** whether the keyboard-focus fix (last commit) actually works —
Troy has not reported back since it was pushed.

## Two known bugs, both from recalling instead of verifying

1. `ClaudeService.model = "claude-sonnet-4-6"` — not a current model ID. The
   first Claude call would fail. **Verify the current ID by searching.** Fixed in S1.
2. `KNVBService` base URL is plain `http://` — App Transport Security would
   block it anyway. Moot: the file is deleted in S1.

## Works and is tested

Photo grouping (2-hour sliding window), EXIF date + GPS extraction, home/away by
GPS radius, hashtag building, carousel ordering. All pure logic in `Utilities/`,
all with tests that run via ⌘U.

## Next up

**S1 — delete the dead data layer, fix the model ID.** Design-free, small model,
net deletion. No blockers.

## Blocked on Troy

1. **Publishing decision, A or B** (`PLAN.md` → Publishing). Blocks S5.
   Recommendation: **B** — export and post from the phone, deleting three
   subsystems and six credentials.
2. **Get a Voetbal Datacentre API key** — either directly if individual signup
   exists, or via the DBS / vv Acht webmaster. Unlocks S7, which removes almost
   all manual entry. Also paste the **initialisatie** chapter of the docs: the
   `PHPSESSID` + `hash` flow must be implemented from the spec, not guessed.
3. **Confirm the app still launches** and text fields now accept input.

## Open threads

- Photos extensions are on disk but not built, and need the €99/year developer
  program plus an Xcode project. Deferred, not cancelled.
- `players/` on the GAP Lab site is empty apart from `.gitkeep`.
- Home venue coordinates for DBS and vv Acht were entered from recall and are
  **unverified** — check them in Settings → Home Venues against Apple Maps
  before trusting the home/away call.
