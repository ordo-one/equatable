import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro that automatically generates an `Equatable` conformance for structs.
///
/// This macro creates a standard equality implementation by comparing all stored properties
/// that aren't explicitly marked to be skipped with `@EquatableIgnored`.
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
public struct EquatableMacro: ExtensionMacro {
    private static let skippablePropertyWrappers: Set = [
        "State",
        "StateObject",
        "ObservedObject",
        "EnvironmentObject",
        "Environment",
        "FocusState",
        "SceneStorage",
        "AppStorage"
    ]

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
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
        let storedProperties = structDecl.memberBlock.members.compactMap { member -> (name: String, type: TypeSyntax?)? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  binding.accessorBlock == nil else {
                return nil
            }

            // Skip properties with SwiftUI attributes (like @State, @Binding, etc.) or if they are marked with @EqutableIgnored
            if Self.shouldSkip(varDecl) {
                return nil
            }

            // Skip static properties
            if Self.isStatic(varDecl) {
                return nil
            }

            // Skip computed properties
            let isStoredProperty = binding.accessorBlock == nil

            if !isStoredProperty {
                return nil
            }

            // if it's a closure marked with @EquatableIgnoredUnsafeClosure allow it but don't compare
            if isMarkedWithEquatableIgnoredUnsafeClosure(varDecl) {
                return nil
            } else {
                // If it's a closure and not marked with @EquatableIgnoredUnsafeClosure throw a diagnostic
                if let typeAnnotation = binding.typeAnnotation?.type {
                    if isClosure(type: typeAnnotation) {
                        let diagnostic = Self.makeClosureDiagnostic(for: varDecl)
                        context.diagnose(diagnostic)
                        return nil
                    }
                } else if let initializer = binding.initializer?.value {
                    // Check if the initializer is a closure expression
                    if initializer.is(ClosureExprSyntax.self) {
                        let diagnostic = Self.makeClosureDiagnostic(for: varDecl)
                        context.diagnose(diagnostic)
                        return nil
                    }
                }
            }

            return (name: identifier, type: binding.typeAnnotation?.type)
        }

        // Sort properties: "id" first, then by type complexity
        let sortedProperties = storedProperties.sorted { lhs, rhs in
            return Self.compare(lhs: lhs, rhs: rhs)
        }

        guard !storedProperties.isEmpty else {
            let diagnostic = Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@Equatable requires at least one equatable stored property.")
            )
            context.diagnose(diagnostic)
            return []
        }

        guard let extensionSyntax = Self.generateEquatableExtensionSyntax(
            sortedProperties: sortedProperties,
            type: type
        ) else {
            return []
        }

        // Check if the type conforms to `Hashable`
        if Self.isHashable(structDecl) {
            // If the type conforms to `Hashable` we need to generate the `Hashable` conformance to match
            // the properties used in `Equatable` implementation
            guard let hashableExtensionSyntax = Self.generateHashableExtensionSyntax(
                sortedProperties: sortedProperties,
                type: type
            ) else {
                return [extensionSyntax]
            }

            return [extensionSyntax, hashableExtensionSyntax]
        } else {
            return [extensionSyntax]
        }
    }

    // Skip properties with SwiftUI attributes (like @State, @Binding, etc.) or if they are marked with @EqutableIgnored
    private static func shouldSkip(_ varDecl: VariableDeclSyntax) -> Bool {
        varDecl.attributes.contains { attribute in
            if let atribute = attribute.as(AttributeSyntax.self),
               Self.shouldSkip(atribute: atribute) {
                return true
            }
            return false
        }
    }

    private static func shouldSkip(atribute node: AttributeSyntax) -> Bool {
        if let identifierType = node.attributeName.as(IdentifierTypeSyntax.self),
           Self.shouldSkip(identifierType: identifierType) {
            return true
        }
        if let memberType = node.attributeName.as(MemberTypeSyntax.self),
           Self.shouldSkip(memberType: memberType) {
            return true
        }
        return false
    }

    private static func shouldSkip(identifierType node: IdentifierTypeSyntax) -> Bool {
        if node.name.text == "EquatableIgnored" {
            return true
        }
        if Self.skippablePropertyWrappers.contains(node.name.text) {
            return true
        }
        return false
    }

    private static func shouldSkip(memberType node: MemberTypeSyntax) -> Bool {
        if node.baseType.as(IdentifierTypeSyntax.self)?.name.text == "SwiftUI",
           Self.skippablePropertyWrappers.contains(node.name.text) {
            return true
        }
        return false
    }

    private static func isStatic(_ varDecl: VariableDeclSyntax) -> Bool {
        varDecl.modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static)
        }
    }

    private static func isHashable(_ structDecl: StructDeclSyntax) -> Bool {
        let existingConformances = structDecl.inheritanceClause?.inheritedTypes
            .compactMap { $0.type.as(IdentifierTypeSyntax.self)?.name.text }
        ?? []
        return existingConformances.contains("Hashable")
    }

    private static func isMarkedWithEquatableIgnoredUnsafeClosure(_ varDecl: VariableDeclSyntax) -> Bool {
        varDecl.attributes.contains(where: { attribute in
            if let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text {
                return attributeName == "EquatableIgnoredUnsafeClosure"
            }

            return false
        })
    }

    private static func compare(lhs: (name: String, type: TypeSyntax?), rhs: (name: String, type: TypeSyntax?)) -> Bool {
        // "id" always comes first
        if lhs.name == "id" { return true }
        if rhs.name == "id" { return false }

        let lhsComplexity = typeComplexity(lhs.type)
        let rhsComplexity = typeComplexity(rhs.type)

        if lhsComplexity == rhsComplexity {
            return lhs.name < rhs.name
        }
        return lhsComplexity < rhsComplexity
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func typeComplexity(_ type: TypeSyntax?) -> Int {
        guard let type else { return 100 } // Unknown types go last

        let typeString = type.description.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        switch typeString {
        case "Bool": return 1
        case "Int", "Int8", "Int16", "Int32", "Int64": return 2
        case "UInt", "UInt8", "UInt16", "UInt32", "UInt64": return 3
        case "Float", "Double": return 4
        case "String": return 5
        case "Character": return 6
        case "Date": return 7
        case "Data": return 8
        case "URL": return 9
        case "UUID": return 10
        default:
            if type.is(OptionalTypeSyntax.self) {
                if let wrappedType = type.as(OptionalTypeSyntax.self)?.wrappedType {
                    return typeComplexity(wrappedType) + 20
                }
            }

            if type.isArray {
                return 30
            }

            if type.isDictionary {
                return 40
            }

            return 50
        }
    }

    private static func makeClosureDiagnostic(for varDecl: VariableDeclSyntax) -> Diagnostic {
        let attribute = AttributeSyntax(
            leadingTrivia: .space,
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier("EquatableIgnoredUnsafeClosure")),
            trailingTrivia: .space
        )
        let existingAttributes = varDecl.attributes
        let newAttributes = existingAttributes + [.attribute(attribute.with(\.leadingTrivia, .space))]
        let fixedDecl = varDecl.with(\.attributes, newAttributes)
        let diagnostic = Diagnostic(
            node: varDecl,
            message: MacroExpansionErrorMessage("Arbitary closures are not supported in @Equatable"),
            fixIt: .replace(
                message: SimpleFixItMessage(
                    message: """
                    Consider marking the closure with\
                    @EquatableIgnoredUnsafeClosure if it doesn't effect the view's body output.
                    """,
                    fixItID: MessageID(
                        domain: "",
                        id: "test"
                    )
                ),
                oldNode: varDecl,
                newNode: fixedDecl
            )
        )

        return diagnostic
    }

    private static func generateEquatableExtensionSyntax(
        sortedProperties: [(name: String, type: TypeSyntax?)],
        type: TypeSyntaxProtocol
    ) -> ExtensionDeclSyntax? {
        let comparisons = sortedProperties.map { property in
            "lhs.\(property.name) == rhs.\(property.name)"
        }.joined(separator: " && ")

        let equalityImplementation = comparisons.isEmpty ? "true" : comparisons

        let extensionDecl: DeclSyntax = """
        extension \(type): Equatable {
            nonisolated public static func == (lhs: \(type), rhs: \(type)) -> Bool {
                \(raw: equalityImplementation)
            }
        }
        """

        return extensionDecl.as(ExtensionDeclSyntax.self)
    }

    private static func generateHashableExtensionSyntax(
        sortedProperties: [(name: String, type: TypeSyntax?)],
        type: TypeSyntaxProtocol
    ) -> ExtensionDeclSyntax? {
        let hashableImplementation = sortedProperties.map { property in
            "hasher.combine(\(property.name))"
        }
            .joined(separator: "\n")

        let hashableExtensionDecl: DeclSyntax = """
        extension \(raw: type) {
            nonisolated public func hash(into hasher: inout Hasher) {
                \(raw: hashableImplementation)
            }
        }
        """

        return hashableExtensionDecl.as(ExtensionDeclSyntax.self)
    }
}

@main
struct EquatablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EquatableMacro.self,
        EquatableIgnoredMacro.self,
        EquatableIgnoredUnsafeClosureMacro.self
    ]
}
