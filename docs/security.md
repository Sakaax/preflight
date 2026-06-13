# Security & threat model — "100% local"

Preflight's core promise is that nothing about your build leaves your machine. This
document spells out what that means and why you can rely on it.

## Properties

### Reads files only

Preflight opens the build artifact you point it at and reads:

- the app `Info.plist`,
- any `PrivacyInfo.xcprivacy` privacy manifests,
- the `Frameworks` directory listing,
- (optionally, opt-in) the app icon image.

It does not read anything outside the build artifact and the temp dir it creates
for `.ipa` extraction.

### Zero network

The `Preflight` library imports `Foundation` and **ZIPFoundation** only (plus an
`#if canImport(ImageIO)` guard for icon extraction). ZIPFoundation is a pure-Swift,
cross-platform unzip library that reads and writes files — it does no networking.
There is **no** `URLSession`, no socket, no HTTP, no
DNS, no analytics, no crash reporting, no telemetry of any kind. It cannot contact
App Store Connect, an LLM, or any server, because no such code exists in the
package. You can verify this by grepping the sources.

### No App Store Connect, no AI, no licensing

These are deliberately *absent* from this package. The core never authenticates,
never holds a key, never sends facts to a model. Because Preflight cannot read your
ASC privacy labels, it is careful to never assert that something is "missing" from
them — it only reports what your build *embeds*, leaving the cross-check to you.

### Never executes the binary

Preflight never runs the app executable or any code from the build. It only parses
data files (`PropertyListSerialization` on plists, a directory listing for
frameworks, image decoding for the optional icon). There is no `dlopen`, no
`Process` invocation of the build, no script execution — and no subprocess at all.

Unzipping an `.ipa` into a temp directory is done in-process by **ZIPFoundation**
(pure Swift, cross-platform) via the default `ZipExtractor` — it reads the archive's
bytes and writes the extracted files, never executing anything. This is isolated
behind the `ArchiveExtractor` protocol so it can be swapped or audited independently.

### Temp directories are cleaned

For `.ipa` parsing, Preflight creates a unique temp directory under the system temp
location, extracts into it, and removes it via `defer` — on success and on every
failure path. No extracted build contents are left behind.

## What Preflight is not responsible for

- The integrity of the build you hand it (it trusts the file you point at).
- Anything a downstream consumer does with the resulting `BuildFacts`/`[Finding]`
  (e.g. if *your* app then sends them somewhere — that's your code, not Preflight's).

## Auditing

The package is small, with a single dependency (ZIPFoundation, pure-Swift unzip).
To verify the network claim:

```bash
grep -rEi 'URLSession|http|socket|Network|telemetry|analytics' Sources/
```

This should return nothing in `Sources/Preflight` (the README and docs mention the
*absence* of these, which is expected).
