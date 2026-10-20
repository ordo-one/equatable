/// The built-in comparison modes for an `@EquatableCompared` property.
public enum EquatableComparison {
    /// Compare class references using `===`, including optional references.
    /// Changes inside the same object do not affect its identity.
    case identity
}

/// Produces the representation used to compare a property and, when applicable, hash it.
///
/// Implementations must be deterministic, free of side effects, and accessible from
/// the isolation context selected by `@Equatable`. The representation must also
/// conform to `Hashable` when the containing type uses generated hashing.
public protocol EquatableComparisonStrategy {
    /// The type of property accepted by the strategy.
    associatedtype Value

    /// The equatable representation produced for comparison and hashing.
    associatedtype ComparisonValue: Equatable

    /// Produces the representation used to compare a property value.
    ///
    /// - Parameter value: The property's current value.
    /// - Returns: A deterministic representation of `value`.
    static func comparisonValue(for value: Value) -> ComparisonValue
}

/// Compares and hashes a property through a key path rooted in the property's type.
///
/// For example, `@EquatableCompared(by: \Document.identifier)` compares the identifier
/// even when `Document` itself is not `Equatable`. Use an explicit root type. Optional
/// chaining follows Swift's normal key-path rules; optional properties require an
/// optional-root key path or a strategy accepting an optional input.
///
/// The selected value must be `Hashable` if the containing type uses generated hashing.
/// The key path is evaluated at comparison time, not captured as a snapshot.
@attached(peer)
public macro EquatableCompared<Root, ComparedValue: Equatable>(by keyPath: KeyPath<Root, ComparedValue>) =
    #externalMacro(module: "EquatableMacros", type: "EquatableComparedMacro")

/// Compares a class reference by identity and hashes its `ObjectIdentifier`.
///
/// Supports optional references: two nil values compare equal. Value types are not
/// supported. Use on an instance stored property inside an `@Equatable` type.
@attached(peer)
public macro EquatableCompared(_ comparison: EquatableComparison) =
    #externalMacro(module: "EquatableMacros", type: "EquatableComparedMacro")

/// Compares and hashes the representation produced by a reusable strategy.
///
/// For example, `@EquatableCompared(using: LowercasedString.self)` can normalize a
/// string before comparison. The strategy's input must accept the property, and its
/// output must be `Hashable` if the containing type uses generated hashing.
///
/// Comparison markers cannot be combined with exclusion markers or automatically
/// skipped SwiftUI property wrappers. Closures and computed properties are unsupported.
@attached(peer)
public macro EquatableCompared<Strategy: EquatableComparisonStrategy>(using strategy: Strategy.Type) =
    #externalMacro(module: "EquatableMacros", type: "EquatableComparedMacro")
