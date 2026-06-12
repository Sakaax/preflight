# Concept — why Preflight exists

## The pain

Shipping an iOS app, the hardest boss fight is rarely the code. It's the App Store
review paperwork: an empty usage string, a missing privacy manifest, a tracking
SDK you forgot to declare, an export-compliance question you answer wrong. Each of
these is a deterministic, *knowable-in-advance* rejection — yet you usually only
discover them after you've waited days in the review queue.

Most of these failures are visible **inside the build artifact you already have on
disk**. The `Info.plist`, the `PrivacyInfo.xcprivacy` manifests, and the bundled
frameworks contain enough information to predict a large class of rejections before
you ever hit "Submit".

## The idea

Preflight reads that build artifact and tells you what's likely to bounce.

- **Parse** the `.ipa` or `.xcarchive` into a structured `BuildFacts` value.
- **Check** those facts with deterministic rules that map to real, frequent App
  Store rejection reasons.
- **Report** blockers / warnings / info, each with a fix.

## What it is *not*

- It is **not** a network tool. It never calls App Store Connect, never phones
  home, never runs an LLM. Everything happens on your machine, from files you
  already have.
- It is **not** a guarantee of approval. It catches a class of deterministic,
  build-visible problems. Reviewers are human; design and content judgments are
  out of scope.
- It is **not** affirmative about things it cannot see. Preflight does not read
  your App Store Connect privacy labels, so it never tells you a label is
  "missing" — only what your build *embeds*, so you can cross-check yourself. A
  false "all clear" followed by a real rejection would be the worst possible bug,
  so the wording is deliberately conservative.

## Scope

iOS build artifacts, Apple platform. The deterministic build-only checks are the
whole product here. Richer cross-checks (reading ASC metadata, AI explanations)
belong to the closed product **Cleared** that this core was extracted from.
