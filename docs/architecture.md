# Architecture

Preflight is split into a **library** (`Preflight`) and a **CLI** (`preflight`).
The library is where everything lives; the CLI is a thin presentation layer.

## Data flow

```
URL  ──▶  BuildParser.parse  ──▶  BuildFacts  ──▶  CheckEngine.run  ──▶  [Finding]
            (reads files)         (pure data)        (pure checks)
```

`Preflight.inspect(at:format:)` wires the whole pipeline:
`parse` → `CheckEngine.buildOnly.run`.

## Layers

### 1. Parsing / IO (`BuildParser`, `ArchiveExtractor`, `AppIconExtractor`)

`BuildParser.parse(at:format:extractor:extractIcon:)`:

- `.xcarchive` → finds the single `*.app` under `Products/Applications`, parses it.
- `.ipa` → makes a temp dir, asks the `ArchiveExtractor` to unzip into it, finds
  the `*.app` under `Payload/`, parses it, and cleans the temp dir via `defer`.
- On failure it returns a minimal `BuildFacts` with a `parseNote` set, never throws.

`parseAppBundle` reads, from the `*.app`:

- `Info.plist` via `PropertyListSerialization` (handles **binary** plists):
  bundle id, app name, versions, min OS, all `*UsageDescription` keys, and the
  `ITSAppUsesNonExemptEncryption` export-compliance key.
- Every `PrivacyInfo.xcprivacy` (root flag + a recursive enumeration), aggregating
  `NSPrivacyTracking`, `NSPrivacyTrackingDomains`, and `NSPrivacyCollectedDataTypes`.
- The `Frameworks` folder (`.framework` / `.dylib`).
- Optionally the app icon (opt-in, ImageIO-guarded).

### 2. The check engine (`Check`, `CheckEngine`, `Checks/`)

A `Check` is `func run(_ facts: BuildFacts) -> [Finding]` — a **pure function**.
`CheckEngine` flat-maps its checks and sorts findings by `(severity, category)`.
`CheckEngine.buildOnly` is the canonical six-check set.

Each `Finding` carries a unique `id`, a **stable `code`** (for downstream
localization), severity, category, English title/message/fix, and an `args`
dictionary of the dynamic data used to build the message.

### 3. The CLI (`Sources/PreflightCLI`)

A `swift-argument-parser` command: `preflight <path> [--json]`. It resolves the
path, calls `Preflight.inspect`, and prints either a readable report or
`{ facts, findings }` JSON (icon data stripped). Advisory exit codes: always `0`
except `1` when the path doesn't exist.

> The executable **target** is named `PreflightCLI`, not `preflight`, to avoid a
> case-insensitive-filesystem collision with the `Preflight` library's build
> directory. The shipped executable is still named `preflight` (the *product*).

## The platform seam

The only platform-specific operation is unzipping an `.ipa`. It lives behind the
`ArchiveExtractor` protocol:

```swift
public protocol ArchiveExtractor: Sendable {
    func extract(_ archive: URL, to destination: URL) throws
}
```

`ZipExtractor` is the default implementation, backed by **ZIPFoundation** (pure
Swift) — so it runs identically on **macOS and Linux**. You can supply your own
conforming type and pass it to `BuildParser.parse(at:extractor:)` if you need a
different backend. Nothing else in the library is platform-bound except opt-in icon
extraction, which is `#if canImport(ImageIO)` guarded and returns `nil` on Linux.

## Concurrency

Everything is value types and pure functions, all `Sendable`, compiling cleanly in
Swift 6 language mode. There is no shared mutable state.
