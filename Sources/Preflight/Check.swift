import Foundation

/// A single deterministic, build-only check.
///
/// Conforming types are pure functions of `BuildFacts`: no network, no state,
/// no side effects. Each returns zero or more `Finding`s.
public protocol Check: Sendable {
    func run(_ facts: BuildFacts) -> [Finding]
}
