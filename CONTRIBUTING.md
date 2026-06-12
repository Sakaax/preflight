# Contributing to Preflight

Thanks for your interest. Preflight is deliberately small and focused; the bar for
new code is "does it stay true to the guarantees below?".

## Build & test

```bash
swift build
swift test
```

Both must pass before you open a PR. The package targets Swift 6 language mode —
keep value types `Sendable` and avoid data races.

## Non-negotiable guarantees

The whole point of Preflight is trust. Any change must preserve:

- **Foundation-only core.** The `Preflight` library imports `Foundation`. The only
  exception is app-icon extraction, which is guarded behind
  `#if canImport(ImageIO)` and falls back to `nil` elsewhere.
- **Zero network. Ever.** No URLSession, no sockets, no telemetry, no analytics.
- **No App Store Connect, no AI, no licensing** in the core. Those belong in
  downstream products, not here.
- **Deterministic.** A check is a pure function of `BuildFacts`. Same input →
  same output. No clocks, no randomness, no environment reads.
- **Never execute the build binary.** We read files; we do not run them.

If a change needs any of the above, it does not belong in this repository.

## Code style

- Swift, Foundation-only core. Clear over clever.
- The parsing/IO layer (`BuildParser`, `ArchiveExtractor`) is separate from the
  checks (`Checks/`) which are separate from the public API surface.
- English strings in `Finding`s. Each finding carries a **stable `code`** and a
  `args` dictionary so downstream code can localize without re-deriving data.

## Adding a check

1. Create a type conforming to `Check` in `Sources/Preflight/Checks/`:

   ```swift
   public struct MyCheck: Check {
       public init() {}
       public func run(_ facts: BuildFacts) -> [Finding] {
           // pure function of `facts`
       }
   }
   ```

2. Give each `Finding` a unique `id`, a stable `code`, the right `severity` and
   `category`, and (where dynamic) populate `args`.
3. Register it in `CheckEngine.buildOnly` (order matters — engine output is sorted
   by severity then category, but the registration order is the canonical list).
4. Add tests in `Tests/PreflightTests/CheckTests.swift`: assert the codes produced
   for representative `BuildFacts`, including the *negative* cases (no finding).
5. If the check reasons about anything not already in `BuildFacts`, extend the
   parser (`BuildParser`) and add a `ParserTests` case that builds a synthetic
   `.app` exercising it.

## A note on wording

Be careful never to state something the library cannot know. Preflight does not
read App Store Connect, so a check must never claim a label is "missing" there —
only describe what the **build embeds**. A false "all clear" or a false "missing"
is the worst possible bug.
