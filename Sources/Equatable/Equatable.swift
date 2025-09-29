/// A macro that automatically generates an `Equatable` conformance for structs.
///
/// This macro creates a standard equality implementation by comparing all stored properties
/// that aren't explicitly marked to be skipped with `@EquatableIgnored.
/// Properties with SwiftUI property wrappers (like `@State`, `@ObservedObject`, etc.)
///
/// Structs with arbitary closures are not supported unless they are marked explicitly with `@EquatableIgnoredUnsafeClosure` -
/// meaning that they are safe because they don't  influence rendering of the view's body.
///
/// Usage:
/// ```swift
/// import Equatable
/// import SwiftUI
///
/// @Equatable
/// struct ProfileView: View {
///     var username: String   // Will be compared
///     @State private var isLoading = false           // Automatically skipped
///     @ObservedObject var viewModel: ProfileViewModel // Automatically skipped
///     @EquatableIgnored var cachedValue: String? // This property will be excluded
///     @EquatableIgnoredUnsafeClosure var onTap: () -> Void // This closure is safe and will be ignored in comparison
///     let id: UUID // will be compared first for shortcircuiting equality checks
///
///     var body: some View {
///         VStack {
///             Text(username)
///             if isLoading {
///                 ProgressView()
///             }
///         }
///     }
/// }
/// ```
///
/// The generated extension will implement the `==` operator with property comparisons
/// ordered for optimal performance (e.g., IDs and simple types first):
/// ```swift
/// extension ProfileView: Equatable {
///     nonisolated public static func == (lhs: ProfileView, rhs: ProfileView) -> Bool {
///         lhs.id == rhs.id && lhs.username == rhs.username
///     }
/// }
/// ```
///
/// If the type is marked as conforming to `Hashable` the compiler synthesized `Hashable` implementation will not be correct.
/// That's why the `@Equatable` macro will also generate a `Hashable` implementation for the type that is aligned with the `Equatable` implementation.
///
/// ```swift
/// import Equatable
/// @Equatable
/// struct User: Hashable {
///     let id: Int
///     @EquatableIgnored var name = ""
/// }
/// ```
///
/// Expanded:
/// ```swift
/// extension User: Equatable {
///     nonisolated public static func == (lhs: User, rhs: User) -> Bool {
///         lhs.id == rhs.id
///     }
/// }
/// extension User {
///     nonisolated public func hash(into hasher: inout Hasher) {
///         hasher.combine(id)
///     }
/// }
/// ```
///
///
/// ## Isolation
/// `Equatable` macro supports generating the conformance with different isolation levels by using the `isolation` parameter.
///  The parameter accepts three values: `.nonisolated` (default), `.isolated`, and `.main` (requires Swift 6.2 or later).
///  The chosen isolation level will be applied to the generated conformances for both `Equatable` and `Hashable` (if applicable).
///
///  ### Nonisolated (default)
///  The generated `Equatable` conformance is `nonisolated`, meaning it can be called from any context without isolation guarantees.
///  ```swift
///  @Equatable(isolation: .nonisolated) (also ommiting the parameter uses this mode)
///    struct Person {
///     let name: String
///     let age: Int
///   }
///  ```
///
///  expands to:
///  ```swift
///  extension Person: Equatable {
///   nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
///     lhs.name == rhs.name && lhs.age == rhs.age
///    }
///  }
///  ```
///
///  ### Isolated
///  The generated `Equatable` conformance is `isolated`, meaning it can only be called from within the actor's context.
///  ```swift
///  @Equatable(isolation: .isolated)
///  struct Person {
///     let name: String
///     let age: Int
///  }
///  ```
///
///  expands to:
///  ```swift
///  extension Person: Equatable {
///   public static func == (lhs: Person, rhs: Person) -> Bool {
///     lhs.name == rhs.name && lhs.age == rhs.age
///    }
///  }
///  ```
///
///  ### Main (requires Swift 6.2 or later)
///  A common case  is to have a `@MainActor` isolated type, SwiftUI views being a common example. Previously, the generated `Equatable` conformance had to be `nonisolated` in order to satisfy the protocol requirement.
///  This would then restrict us to access only nonisolated properties of the type in the generated `Equatable` function — which ment that we had to ignore all `@MainActor` isolated properties in the equality comparison.
///  Swift 6.2 introduced [isolated confomances](https://docs.swift.org/compiler/documentation/diagnostics/isolated-conformances/) allowing us to generate  `Equatable` confomances
///  which are bound to the `@MainActor`. In this way the generated `Equatable` conformance can access `@MainActor` isolated properties of the type synchonously and the compiler will guarantee that the confomance
///  will be called only from the `@MainActor` context.
///
///  We can do so by specifying `@Equatable(isolation: .main)`, e.g:
///  ```swift
///  @Equatable(isolation: .main)
///  @MainActor
///  struct Person {
///     let name: String
///     let age: Int
///  }
///  ```
///
///  expands to:
///  ```swift
///  extension Person: Equatable {
///     public static func == (lhs: Person, rhs: Person) -> Bool {
///         lhs.name == rhs.name && lhs.age == rhs.age
///     }
///  }
///  ```
///
@attached(extension, conformances: Equatable, Hashable, names: named(==), named(hash(into:)))
public macro Equatable(isolation: Isolation = .nonisolated) = #externalMacro(module: "EquatableMacros", type: "EquatableMacro")

/// Isolation level for the generated Equatable functions.
public enum Isolation {
    /// The generated `Equatable` conformance is `nonisolated`.
    case nonisolated
    /// The generated `Equatable` conformance is`isolated`.
    case isolated
    #if swift(>=6.2)
        /// The generated `Equatable` conformance is `@MainActor` isolated.
        case main
    #endif
}

/// A peer macro that marks properties to be ignored in `Equatable` conformance generation.
///
/// This macro allows developers to explicitly exclude specific properties from the equality comparison
/// when using the `@Equatable` macro. It performs validation to ensure it's used correctly.
///
/// Usage:
/// ```swift
/// @Equatable
/// struct User {
///     let id: UUID
///     let name: String
///     @EquatableIgnored var temporaryCache: [String: Any] // This property will be excluded
/// }
/// ```
///
/// This macro cannot be applied to:
/// - Non-property declarations
/// - Closure properties
/// - Properties already marked with `@Binding`
@attached(peer)
public macro EquatableIgnored() = #externalMacro(module: "EquatableMacros", type: "EquatableIgnoredMacro")

/// A macro that makes closure properties safely participate in `Equatable` conformance.
///
/// ## Overview
///
/// Closures aro not diffable by default and not allowed  when applying the `@Equatable` macro.
/// Apply the `@EquatableIgnoredUnsafeClosure` attribute to closure which are safe to be excluded from equality comparisons.
/// Only closures that do not capture value types on call site and do not influence rendering of the view's body are safe to be marked with this attribute.
///
/// ## Exammple - Safe Usage of `@EquatableIgnoredUnsafeClosure`
///
/// Apply the `@EquatableIgnoredUnsafeClosure` attribute to closure properties in your type:
///
/// ```swift
/// struct UserActions: Equatable {
///     let id: UUID
///     let name: String
///
///     @EquatableIgnoredUnsafeClosure
///     var onTap: () -> Void
/// }
///
/// struct ContentView: View {
///     var body: some View {
///         UserActions(id: UUID(), name: "Example") {
///             print("User tapped") // This closure does not capture value types on call site
///                                  // and does not influence rendering of `UserActions` view's body.
///         }
///     }
/// }
/// ```
///
/// In this example, `onTap` will be excluded from equality comparisons, allowing the `UserActions` instances to be properly compared based only on `id` and `name`.
///
/// ## Example - Unsafe Usage of `@EquatableIgnoredUnsafeClosure`
/// ```swift
/// struct DemoView: View {
///     @State var enabled = false
///
///     var body: some View {
///         Text("Enabled? \(enabled)")
///         .onTapGesture(perform: {
///             enabled.toggle()
///         })
///         Content(enabled: enabled)
///     }
/// }
///
/// struct Content: View {
///     var enabled: Bool
///     var body: some View {
///         ViewTakesClosure(
///         label: "This view takes a closure",
///         onTapGesture: {
///             // This will always print "enabled? False", because this `ViewTakesClosure`
///             // is never re-rendered (its Equatable inputs never change).
///             // The closure captures the initial value of `enabled=false`.
///             print("enabled? \(enabled)")
///         })
///     }
/// }
///
/// @Equabable
/// struct ViewTakesClosure: View {
///     let label: String
///     @EquatableIgnoredUnsafeClosure let onTapGesture: () -> Void
///
///     var body: some View {
///         Text(label)
///         .onTapGesture(perform: onTapGesture)
///     }
/// }
/// ```
///
/// In this example `ViewTakesClosure`'s closure captures the `enabled` value on callsite and since it's marked with `@EquatableIgnoredUnsafeClosure`
/// it will not cause a re-render when the value of `enabled` changes. The closure will always print the initial value of `enabled` which is an incorrect behavior.
///
/// ## Requirements
///
/// - The decorated property must be a closure type
@attached(peer)
public macro EquatableIgnoredUnsafeClosure() = #externalMacro(module: "EquatableMacros", type: "EquatableIgnoredUnsafeClosureMacro")
