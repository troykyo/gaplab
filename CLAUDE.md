# CLAUDE.md — MatchPost

Conventions and environment facts. Auto-loaded every session. Keep this short.

---

## Environment — read this first

**This container is Linux with no Swift toolchain and no Xcode.** Verified:
`swift`, `xcodebuild`, `xcrun` are all absent.

Consequences, which are not negotiable:

- I can **author** Swift, but I can **never compile, run, or test it here**.
- Every Swift file I write is **unverified** until Troy builds it on his Mac.
- The loop is: **I author → Troy builds in Xcode → Troy pastes errors → I fix.**
- Therefore: prefer boring, conventional Swift. Do not use clever generics,
  obscure API, or anything whose signature I am recalling rather than certain of.
- When unsure of an initializer or method signature, say so in the handoff notes
  rather than guessing silently.

**Troy's machine:** macOS, Xcode, repo at `~/Github/gaplab`. He opens
`MatchPost/Package.swift` in Xcode and runs with ⌘R.

## Verify, don't recall

Anything about a third-party platform's *present* state gets **searched, not
remembered**: model IDs, API versions and hosts, account requirements, platform
policies. Training data has a cutoff; these move.

Two bugs already shipped from recalling instead of verifying — a stale Claude
model ID and a fabricated `http://` API host. Cite sources when it matters.

## Project layout

```
MatchPost/
  Package.swift              single executable target + test target
  Sources/MatchPost/
    App/                     entry point, AppState, PersistenceController
    Models/                  CoreData entities (+CoreData.swift) and value types
    Services/                one type per external system (network I/O lives here)
    Utilities/               pure functions, no I/O, no CoreData — easiest to test
    Views/                   SwiftUI views
    ViewModels/              @MainActor ObservableObject, one per screen
  Tests/MatchPostTests/
docs/                        PLAN.md, SPRINTS.md, STATE.md
```

`Sources/MatchPostProject/` and `Sources/MatchPostEditing/` are Photos app
extensions that are **not built** — SwiftPM cannot produce loadable `.appex`
bundles. They are a blueprint for a future Xcode-project migration. Do not
add targets for them to `Package.swift`.

## Swift conventions

- macOS 14+, SwiftUI, CoreData, Swift 5.9. No third-party dependencies.
- CoreData entities: `codeGenerationType="none"`, hand-written
  `Name+CoreData.swift` with `@objc(Name)` and `@NSManaged` properties.
  **The `.xcdatamodeld` XML and the Swift file must be edited together** — a
  property in one and not the other fails at runtime, not compile time.
- Views own no business logic. ViewModels are `@MainActor`, expose `@Published`
  state, and are the only place `Task { }` is started.
- Services throw `AppError`. Never `fatalError` outside `PersistenceController`.
- Custom views used as `Thing("label", …)` need an explicit
  `init(_ label: String, …)` — the memberwise init requires `label:` and will
  not compile at the call site. This has bitten us once.

## Design tokens

Visual constants live in **one** file, `Views/DesignTokens.swift`, as
`enum Tokens { enum Spacing … enum Radius … enum Palette … }`.

**Raw values never appear at call sites.** No `padding(12)`, no
`cornerRadius(8)`, no `Color.blue` in a view body — use `Tokens.Spacing.md`,
`Tokens.Radius.card`, `Tokens.Palette.accent`. If a token is missing, add it
to the file rather than inlining a number.

## Tests

Pure logic in `Utilities/` is expected to have tests: grouping, sorting,
parsing, hashtag building, EXIF, geo. These run on Troy's Mac via ⌘U.

- XCTest, one test file per type under test.
- CoreData tests use `PersistenceController(inMemory: true)`.
- **Do not write tests for views, or for anything requiring network.**
- Every test must assert a behaviour we would actually care about breaking.
  A test that restates the implementation is worse than no test.

## Secrets — never in this repo

API keys and tokens live in the macOS Keychain (service `com.troykyo.matchpost`),
with a fallback file at `~/.matchpost/credentials` (outside the repo, `chmod 600`).

Never commit a key, never put one in `Info.plist`, a source file, or these docs.
Never paste a real key into a commit message or a doc example — use `sk-ant-...`.

## Working rhythm

- **One sprint = one session = one commit.** Start each build session fresh.
- A sprint touches **3–6 files**. If it can't be described that way, split it.
- **Every sprint ends green**: compiles on Troy's Mac, tests pass, committed.
- Update `docs/STATE.md` at the end of every session — it is how the next
  session avoids re-exploring the repo.
- Commit and push each increment with a message saying what changed and why.

## Voice

The app UI is **English**. Football terminology is British/European — match not
game, shirt not jersey, pitch not field, Striker/Winger/Centre Back for
positions. Hashtags are English only. Generated Instagram captions are the one
exception: they are deliberately bilingual Dutch/English.

Do not introduce Dutch into UI labels. This was gotten wrong once.
