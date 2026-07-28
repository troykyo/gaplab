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

The KNVB research killed two services. Remove them rather than leave fiction in
the tree, and fix the two bugs found in the same audit.

- Delete `Services/KNVBService.swift` and `Services/VoetbalScraper.swift`
- Remove the KNVB path from `AddMatchViewModel.analyze()` — manual entry becomes
  the only path to match details
- Remove `knvbAPIKey` from `KeychainKey` and its row in `SettingsView`
- **Fix the Claude model ID** in `ClaudeService` — `claude-sonnet-4-6` is not a
  current model and the first API call would fail. **Verify the current ID by
  searching; do not recall it.**
- Delete `KNVBMatch` / `KNVBMatchRow` and the match-picker step in `AddMatchView`

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

## S7 — Club data integration *(optional)*
**Design gate:** none, but **blocked on Troy emailing the club** · **Model:** small

Only worth doing if DBS or vv Acht hand over their Sportlink `client_id`.
Gives automated fixtures *and* results, legitimately.

- `Services/SportlinkService.swift` against `data.sportlink.com` with the
  club's `client_id`, article `uitslagen`, filtered by `teamcode`
- Fall back silently to manual entry when it returns nothing
- **Never** reuse a `client_id` found in someone else's page HTML

*Fixtures-only alternative if the club says no: parse the tokenised iCal feed.
Gives date, opponent, home/away, venue — no scores.*

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
