# MatchPost — State

Where we are right now. Read at the start of every session. Keep under a page.

**Updated:** 2026-07-28 · **Branch:** `claude/soccer-match-instagram-app-bPEYF`

---

## Last session

Adopted the working method. Wrote `CLAUDE.md`, `docs/PLAN.md`, `docs/SPRINTS.md`
and this file. **No application code changed.**

Two research findings landed, and one research task died:

- **KNVB data: partly settled.** Solid: voetbal.nl's terms prohibit scraping, so
  `VoetbalScraper.swift` goes in S1. Also solid: working integrations use
  `data.sportlink.com` with a **club-owned `client_id`**. **Not verified:** the
  present state of `api.knvbdataservice.nl` — this container's egress allowlist
  blocks all Dutch domains, so neither the agent nor I ever loaded it. An
  earlier claim that it is "dead" was overstated and has been corrected in
  `PLAN.md`. `KNVBService.swift` is **quarantined, not deleted**, pending
  Troy's check. Manual entry is the primary path either way.
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
2. **Email the DBS / vv Acht webmaster** asking for their Sportlink
   `client_id`. Costs nothing to ask; unlocks legitimate automated results (S7).
3. **Confirm the app still launches** and text fields now accept input.

## Open threads

- Photos extensions are on disk but not built, and need the €99/year developer
  program plus an Xcode project. Deferred, not cancelled.
- `players/` on the GAP Lab site is empty apart from `.gitkeep`.
- Home venue coordinates for DBS and vv Acht were entered from recall and are
  **unverified** — check them in Settings → Home Venues against Apple Maps
  before trusting the home/away call.
