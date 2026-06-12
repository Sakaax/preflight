import Foundation

/// How serious a finding is.
public enum Severity: Int, Comparable, Codable, Sendable {
    case error = 0
    case warning = 1
    case info = 2

    public static func < (a: Severity, b: Severity) -> Bool {
        a.rawValue < b.rawValue
    }
}

/// The App Store review category a finding belongs to.
public enum Category: String, Codable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
}

/// A single deterministic finding produced by a `Check`.
public struct Finding: Identifiable, Equatable, Codable, Sendable {
    /// Unique per instance, e.g. `"A.usage.empty.NSCameraUsageDescription"`.
    public let id: String
    /// Stable template key, e.g. `"usage.empty"` — meant for downstream localization.
    public let code: String
    public let severity: Severity
    public let category: Category
    /// The Apple guideline reference, if applicable (e.g. `"5.1.1"`).
    public let guideline: String?
    /// English title.
    public let title: String
    /// English message.
    public let message: String
    /// English fix suggestion, if any.
    public let fix: String?
    /// Dynamic data used to build the message — for downstream localization.
    public let args: [String: String]

    public init(
        id: String,
        code: String,
        severity: Severity,
        category: Category,
        guideline: String?,
        title: String,
        message: String,
        fix: String?,
        args: [String: String] = [:]
    ) {
        self.id = id
        self.code = code
        self.severity = severity
        self.category = category
        self.guideline = guideline
        self.title = title
        self.message = message
        self.fix = fix
        self.args = args
    }
}
