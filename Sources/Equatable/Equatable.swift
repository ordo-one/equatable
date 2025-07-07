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
/// If tye type is marked as conforming to `Hashable`  the compiler synthensized `Hashable` implementation will not be correct.
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
@attached(extension, conformances: Equatable, Hashable, names: named(==), named(hash(into:)))
public macro Equatable() = #externalMacro(module: "EquatableMacros", type: "EquatableMacro")

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
