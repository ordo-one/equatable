import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
public struct EquatableMacro: ExtensionMacro {
    static let skippablePropertyWrappers: Set = [
        "AccessibilityFocusState",
        "AppStorage",
        "Bindable",
        "Environment",
        "EnvironmentObject",
        "FetchRequest",
        "FocusState",
        "FocusedObject",
        "FocusedValue",
        "GestureState",
        "NSApplicationDelegateAdaptor",
        "Namespace",
        "ObservedObject",
        "PhysicalMetric",
        "ScaledMetric",
        "SceneStorage",
        "SectionedFetchRequest",
        "State",
        "StateObject",
        "UIApplicationDelegateAdaptor",
        "WKApplicationDelegateAdaptor",
        "WKExtensionDelegateAdaptor"
    ]

    // swiftlint:disable:next function_body_length
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract isolation argument from the macro
        let isolation = extractIsolation(from: node) ?? .nonisolated
        // Ensure we're attached to a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@Equatable can only be applied to structs")
            )
            context.diagnose(diagnostic)
            return []
        }

        // Extract stored properties
        var storedProperties: [(name: String, type: TypeSyntax?)] = []
        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  binding.accessorBlock == nil,
                  !varDecl.isStatic else {
                continue
            }

            if Self.shouldSkip(varDecl) {
                continue
            }

            if isMarkedWithEquatableIgnoredUnsafeClosure(varDecl) {
                continue
            }

            // Check if it's a closure that should trigger diagnostic
            let isClosureProperty = (binding.typeAnnotation?.type).map(isClosure) == true ||
                (binding.initializer?.value.is(ClosureExprSyntax.self) ?? false)

            if isClosureProperty {
                let diagnostic = Self.makeClosureDiagnostic(for: varDecl)
                context.diagnose(diagnostic)
                continue
            }

            storedProperties.append((name: identifier, type: binding.typeAnnotation?.type))
        }

        // Sort properties: "id" first, then by type complexity
        let sortedProperties = storedProperties.sorted { lhs, rhs in
            Self.compare(lhs: lhs, rhs: rhs)
        }

        guard let extensionSyntax = Self.generateEquatableExtensionSyntax(
            sortedProperties: sortedProperties,
            type: type,
            isolation: isolation
        ) else {
            return []
        }

        // If the type conforms to `Hashable`, always generate a corresponding hash function aligned with the `Equatable` implementation
        if structDecl.isHashable {
            guard let hashableExtensionSyntax = Self.generateHashableExtensionSyntax(
                sortedProperties: sortedProperties,
                type: type,
                isolation: isolation
            ) else {
                return [extensionSyntax]
            }
            return [extensionSyntax, hashableExtensionSyntax]
        } else {
            return [extensionSyntax]
        }
    }
}
