# MatchPost — Sprints

Session-sized units. **One sprint = one session = one commit.** Each touches
3–6 files and ends green (compiles on Troy's Mac, tests pass, committed).

**Design gate** marks sprints that need a decision or an opinion from Troy
before they can start. Everything unmarked can run without him.

**Model** is a dial Troy controls, not a silent downgrade. Mechanical sprints
run fine on a smaller model; design-sensitive and architecturally tricky ones
are worth the larger one.

---

## S1 — Delete the dead data layer, fix the two known bugs
**Design gate:** none · **Model:** small · **Status:** next

Take the lookup path out of the critical path, and fix the model ID.

- **Delete `Services/VoetbalScraper.swift`** — voetbal.nl's terms prohibit
  scripts and robots. Solid ground, delete outright.
- **Quarantine `Services/KNVBService.swift`, do not delete it.** The API is
  confirmed live (see `PLAN.md`) but its host, path and auth flow in this file
  are all wrong — invented from recall. Unwire it so nothing calls it, and
  leave a header comment recording the verified host
  (`https://api.voetbaldatacentre.nl/api/`) and the `PHPSESSID` + `hash` flow,
  so S7 rewrites from facts rather than re-deriving them.
- Remove the lookup path from `AddMatchViewModel.analyze()` — manual entry
  becomes the only route to match details
- **Fix the Claude model ID** in `ClaudeService` — `claude-sonnet-4-6` is not a
  current model and the first API call would fail. **Verify the current ID by
  searching; do not recall it.**
- Remove the match-picker step from `AddMatchView` (keep `KNVBMatch` as a
  value type — it costs nothing and S7 would want it back)
- Keep `knvbAPIKey` in `KeychainKey`; harmless, and removing it is churn

*Files: ~6. Net deletion. This sprint should make the app smaller.*

## S2 — Manual match entry as the primary path
**Design gate:** none · **Model:** small

With the lookup gone, the manual form carries the whole job — so it has to be
fast. Target: opponent and score entered in under ten seconds.

- Pre-fill date, home/away and venue from `StagedPostGroup` (already computed)
- Opponent field with autocomplete from previously-entered opponents
- Score as two steppers, defaulting to 0–0
- Remember the last competition entered and default to it
- Skip straight from queue → form → caption, with no dead steps in between

*Files: `AddMatchView`, `AddMatchViewModel`, `ManualMatchForm`, + 1 test.*

## S3 — First verified Claude call
**Design gate:** none · **Model:** medium · **Needs:** API key in place

The first time any network code in this project actually runs. Nothing past
this point is real until this sprint passes.

- Confirm the corrected model ID against the live API
- Generate one caption end-to-end from a real staged group
- Handle the failure modes properly: bad key, rate limit, malformed JSON,
  network down — each with a message that says what to do about it
- Log the raw response on parse failure so the next fix isn't guesswork

*Files: `ClaudeService`, `AppError`, `AddMatchViewModel`, `AddMatchView`.*

## S4 — Design tokens
**Design gate:** YES — needs Troy's palette and spacing opinion · **Model:** medium

`CLAUDE.md` mandates that raw values never appear at call sites. The rule
currently has no file behind it, and every view is full of `padding(12)` and
`Color.blue`.

- Create `Views/DesignTokens.swift`: `Tokens.Spacing`, `.Radius`, `.Palette`,
  `.Typography`
- Sweep raw values out of `PostingQueueView` and `AddMatchView` first — the two
  screens Troy actually looks at
- Remaining views follow in S4b, which is mechanical once the pattern is set

*Files: `DesignTokens.swift` + 2 views. **S4b** sweeps the other four cheaply.*

## S5 — Publishing
**Design gate:** YES — blocked on the A/B decision in `PLAN.md` · **Model:** medium

**Do not start this sprint until Troy chooses.** Recommendation is B.

**If B (export — recommended):** write ordered images + caption to a dated
folder, copy the caption to the clipboard, reveal in Finder. Then *delete*
`InstagramService` and `ImageHostingService`, and remove six credentials from
Settings. Small sprint, large deletion.

**If A (direct API):** first re-run the Instagram research that died on a spend
limit — current API, account requirements, **and Meta's policy on API
publishing to a minor's account**. That verification is its own sprint (S5-pre)
and A cannot be built responsibly before it lands.

## S6 — GAP Lab player page
**Design gate:** YES — it's a public page on the lab's site · **Model:** medium

- `HTMLProfileGenerator` output reviewed against the real site's look
- Write into `players/` and commit alongside the static site
- Career timeline, match record, best photos

*Lowest priority: needs a career record worth showing, so it wants a few
matches in the database first.*

## S7 — Voetbal Datacentre API
**Design gate:** none, but **blocked on obtaining an API key** · **Model:** medium

Promoted from "optional" — the API is confirmed live and returns everything
`MatchRecord` needs in one call. This removes nearly all manual entry.

- Rewrite `KNVBService.swift` against the verified surface: host
  `https://api.voetbaldatacentre.nl/api/`, the `PHPSESSID` + client-side `hash`
  auth flow, and `GET /api/wedstrijden`
- Decode the listing and filter to his team via `ThuisTeamId` / `UitTeamId` —
  which also gives **exact** home/away, replacing the GPS inference
- Match a `StagedPostGroup` to a fixture by date, then pre-fill opponent,
  score, competition and venue
- Fall back silently to manual entry (S2) whenever there is no key, no network,
  or no fixture on that date — S2 stays the path that always works
- **Never** reuse a `client_id` or key found in someone else's page HTML

*Needs before starting: the key, plus the **initialisatie** chapter of the docs
(how `PHPSESSID` is obtained and how `hash` is computed). Do not guess the hash
algorithm — that is precisely the kind of recall that produced the wrong host
in the first place.*

---

## Sequencing notes

- **S1 → S2 → S3 is the critical path.** After S3 the app does its actual job
  end-to-end, minus publishing.
- **S4 and S6 need Troy's eye. S1, S2, S3, S7 do not** — they can run while
  design decisions are still open, so Troy is never the bottleneck for work
  that never needed him.
- **S4 before S4b, deliberately.** Set the token pattern carefully on two
  screens, and the remaining four become mechanical and cheap.
- **S5 is the only hard block.** Everything else can proceed around it.
