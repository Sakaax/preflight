import ArgumentParser
import Foundation
import Preflight

@main
struct PreflightCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preflight",
        abstract: "Parse an iOS build artifact (.ipa / .xcarchive) and run deterministic build-only checks.",
        version: Preflight.version
    )

    @Argument(help: "Path to the .ipa or .xcarchive to inspect.")
    var path: String

    @Flag(name: .long, help: "Emit JSON ({ facts, findings }) instead of a readable report.")
    var json: Bool = false

    func run() throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            FileHandle.standardError.write(Data("error: no file at \(url.path)\n".utf8))
            throw ExitCode(1)
        }

        let (facts, findings) = Preflight.inspect(at: url)

        if json {
            try printJSON(facts: facts, findings: findings)
        } else {
            printReport(facts: facts, findings: findings)
        }
    }

    // MARK: - JSON output

    private func printJSON(facts: BuildFacts, findings: [Finding]) throws {
        var factsForOutput = facts
        factsForOutput.iconData = nil // never embed binary blobs in the JSON

        struct Output: Encodable {
            let facts: BuildFacts
            let findings: [Finding]
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Output(facts: factsForOutput, findings: findings))
        if let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    // MARK: - Readable report

    private func printReport(facts: BuildFacts, findings: [Finding]) {
        let name = facts.appName ?? "(unknown app)"
        let version = facts.shortVersion ?? "?"
        let build = facts.buildNumber ?? "?"
        let bundle = facts.bundleId ?? "(unknown bundle id)"

        print("Preflight \(Preflight.version)")
        print("=========================================")
        print("App:        \(name)")
        print("Version:    \(version) (\(build))")
        print("Bundle ID:  \(bundle)")
        print("Format:     \(facts.format.rawValue)")
        print("Frameworks: \(facts.frameworks.count)")
        print("Privacy manifest at root: \(facts.hasRootPrivacyManifest ? "yes" : "no")")

        if let note = facts.parseNote {
            print("")
            print("Note: \(note)")
        }

        print("")
        if findings.isEmpty {
            print("No findings. (This is advisory — it does not read App Store Connect.)")
        } else {
            print("Findings (\(findings.count)):")
            print("-----------------------------------------")
            for finding in findings {
                let marker: String
                switch finding.severity {
                case .error: marker = "[BLOCKER]"
                case .warning: marker = "[WARN]   "
                case .info: marker = "[INFO]   "
                }
                print("\(marker) \(finding.title)")
                print("          \(finding.message)")
                if let fix = finding.fix {
                    print("          Fix: \(fix)")
                }
                print("")
            }
        }

        let errors = findings.filter { $0.severity == .error }.count
        let warnings = findings.filter { $0.severity == .warning }.count
        let infos = findings.filter { $0.severity == .info }.count
        print("Summary: \(errors) blocker(s), \(warnings) warning(s), \(infos) info.")
    }
}
