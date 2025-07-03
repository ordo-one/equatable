import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// A macro that automatically generates an `Equatable` conformance for structs.
///
/// This macro creates a standard equality implementation by comparing all stored properties
/// that aren't explicitly marked to be skipped with `@EquatableIgnored`. Properties with SwiftUI property wrappers
/// (like `@State`, `@ObservedObject`, etc.)
///
/// Structs with arbitary closures are not supported unless they are marked explicitly with `@EquatableSafeClosure` -
/// meaning that they are safe because they don't  influence rendering of the view's body.
///
/// Usage:
/// ```swift
/// import SwiftUI
///
/// @Equatable
/// struct ProfileView: View {
///     var username: String   // Will be compared
///     @State private var isLoading = false           // Automatically skipped
///     @ObservedObject var viewModel: ProfileViewModel // Automatically skipped
///     @EquatableIgnored var cachedValue: String? // This property will be excluded
///     @EquatableSafeClosure var onTap: () -> Void // This closure is safe and will be ignored in comparison
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
///
public struct EquatableMacro: ExtensionMacro {
    private static let skippablePropertyWrappers = [
        "State",
        "StateObject",
        "ObservedObject",
        "EnvironmentObject",
        "Environment",
        "FocusState",
        "SceneStorage",
        "AppStorage"
    ]

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
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
            let shouldSkip = varDecl.attributes.contains { attribute in
                if let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text {
                    return attributeName == "EquatableIgnored" || Self.skippablePropertyWrappers.contains(attributeName)
                }
                return false
            }

            if shouldSkip {
                return nil
            }

            // Skip static properties
            let isStatic = varDecl.modifiers.contains { modifier in
                modifier.name.tokenKind == .keyword(.static)
            }

            if isStatic {
                return nil
            }

            // Skip computed properties
            let isStoredProperty = binding.accessorBlock == nil

            if !isStoredProperty {
                return nil
            }

            // if it's a closure marked with @EquatableSafeClosure allow it but don't compare
            if isMarkedWithEquatableSafeClosure(varDecl) {
                return nil
            } else {
                // If it's a closure and not marked with @EquatableSafeClosure throw a diagnostic
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

        guard !storedProperties.isEmpty else {
            let diagnostic = Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@Equatable requires at least one equatable stored property.")
            )
            context.diagnose(diagnostic)
            return []
        }

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

        guard let extensionSyntax = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionSyntax]
    }

    private static func isMarkedWithEquatableSafeClosure(_ varDecl: VariableDeclSyntax) -> Bool {
        return varDecl.attributes.contains(where: { attribute in
            if let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text {
                return attributeName == "EquatableSafeClosure"
            }

            return false
        })
    }

    private static func typeComplexity(_ type: TypeSyntax?) -> Int {
        guard let type = type else { return 100 } // Unknown types go last

        let typeString = type.description.trimmingCharacters(in: .whitespacesAndNewlines)

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

            if typeString.hasPrefix("[") && typeString.hasSuffix("]") {
                return 30
            }

            if typeString.contains(":") && typeString.hasPrefix("[") {
                return 40
            }

            return 50
        }
    }

    private static func makeClosureDiagnostic(for varDecl: VariableDeclSyntax) -> Diagnostic {
        let attribute = AttributeSyntax(
            leadingTrivia: .space,
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier("EquatableSafeClosure")),
            trailingTrivia: .space
        )
        let existingAttributes = varDecl.attributes
        let newAttributes = existingAttributes + [.attribute(attribute.with(\.leadingTrivia, .space))]
        let fixedDecl = varDecl.with(\.attributes, newAttributes)
        let diagnostic = Diagnostic(
            node: varDecl,
            message: MacroExpansionErrorMessage("Arbitary closures are not supported in @Equatable"),
            fixIt: .replace(
                message: SimpleFixItMessage(message: "Consider marking the closure with @EquatableSafeClosure if it doesn't effect the view's body output.", fixItID: .init(domain: "", id: "test")),
                oldNode: varDecl,
                newNode: fixedDecl
            )
        )

        return diagnostic
    }
}

@main
struct EquatablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EquatableMacro.self,
        EquatableIgnoredMacro.self,
        EquatableSafeClosureMacro.self
    ]
}

struct SimpleFixItMessage: FixItMessage {
    let message: String
    let fixItID: MessageID
}
