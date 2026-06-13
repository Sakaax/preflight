# CLAUDE.md — Preflight

Entry point for any agent session on this repo. Read this first.

## Before you start

1. Read `README.md` and the `docs/` (concept, architecture, security).
2. Use the **Context7 MCP** for any API doc lookup (SwiftUI, Foundation,
   PropertyListSerialization, ImageIO, swift-argument-parser). Don't trust memory
   for API details — they change.

## What Preflight is

A standalone Swift package: a library (Foundation + ZIPFoundation) that opens an
iOS build (`.ipa` / `.xcarchive`), extracts `BuildFacts`, and runs deterministic
build-only `Check`s, plus a thin CLI (`preflight`). Cross-platform (macOS + Linux).
It is the open-source core extracted from the closed product **Cleared**.

Data flow: `URL → BuildParser.parse → BuildFacts → CheckEngine.buildOnly.run → [Finding]`.

## Hard rules (never break these)

- **Dependencies stay minimal.** The core uses Foundation plus one dependency —
  ZIPFoundation (pure-Swift, cross-platform unzip). The only platform-guarded code
  is app-icon extraction, guarded by `#if canImport(ImageIO)`.
- **Zero network. Ever.** No URLSession, no telemetry.
- **No App Store Connect, no AI, no licensing, no network in the core.** Those
  live downstream in Cleared, never here. Don't add them.
- **Deterministic.** Every `Check` is a pure function of `BuildFacts`.
- **Never execute the build binary.** Read files only; clean temp dirs.
- **Never claim something the lib can't know.** Preflight doesn't read ASC labels,
  so a check must never say a label is "missing" — only what the build *embeds*.

## The platform seam (cross-platform)

The one platform-specific operation — unzipping an `.ipa` — is behind the
`ArchiveExtractor` protocol. `ZipExtractor` is the default impl, backed by
**ZIPFoundation** (pure Swift), so it runs identically on **macOS and Linux**. CI
builds and tests on both (see `.github/workflows/ci.yml`).

## Build discipline

Always run `swift build` then `swift test` after a change; both must pass under
Swift 6 language mode (keep value types `Sendable`).

## Layout

- `Sources/Preflight/` — the library (Foundation-only core).
  - `Checks/` — one file per check family.
  - `ArchiveExtractor.swift` — the platform seam.
- `Sources/PreflightCLI/` — the executable target (product name `preflight`).
  - Note: the target is named `PreflightCLI` (not `preflight`) because the
    filesystem is case-insensitive and a lowercase `preflight` target collides
    with the `Preflight` library's build directory.
- `Tests/PreflightTests/` — swift-testing suites.
