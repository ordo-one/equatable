import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
public struct EquatableIgnoredMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first
        else {
            let diagnostic = Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@EquatableIgnored can only be applied to properties")
            )
            context.diagnose(diagnostic)
            return []
        }

        if let typeAnnotation = binding.typeAnnotation?.type {
            if isClosure(type: typeAnnotation) {
                let diagnostic = Diagnostic(
                    node: node,
                    message: MacroExpansionErrorMessage("@EquatableIgnored cannot be applied to closures")
                )
                context.diagnose(diagnostic)
            }
        }

        // Should not be applied to @Binding
        let hasBinding = varDecl.attributes.contains { attribute in
            if let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text {
                return attributeName == "Binding"
            }
            return false
        }

        guard !hasBinding else {
            let diagnostic = Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@EquatableIgnored cannot be applied to @Binding properties")
            )
            context.diagnose(diagnostic)
            return []
        }

        guard varDecl.attributes.allSatisfy({
            $0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.trimmed.description != "FocusedBinding"
        }) else {
            let diagnostic = Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@EquatableIgnored cannot be applied to @FocusedBinding properties")
            )
            context.diagnose(diagnostic)
            return []
        }

        return []
    }
}
