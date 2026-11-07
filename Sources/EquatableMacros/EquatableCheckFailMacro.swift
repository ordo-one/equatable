import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The expansion of `@_EquatableCheck` when the compiler fell back to the unconstrained overload,
/// meaning the property's type is neither `Equatable` nor a class. Emits an error on the property
/// instead of letting the generated `==` fail to compile.
public struct EquatableCheckFailMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        else {
            context.diagnose(Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@_EquatableCheck can only be applied to properties")
            ))
            return []
        }

        let message = if let type = binding.typeAnnotation?.type {
            "Property '\(identifier)' of type '\(type.trimmedDescription)' does not conform to 'Equatable'"
        } else {
            "Property '\(identifier)' does not conform to 'Equatable'"
        }

        let anchor = if let type = binding.typeAnnotation?.type {
            Syntax(type)
        } else {
            Syntax(binding.pattern)
        }

        // `@EquatableIgnored` takes over the declaration's leading trivia so it ends up on the same line,
        // in front of the declaration. The `@_EquatableCheck` attribute is dropped: `@Equatable` adds it
        // again on the next expansion anyway, and it must not leak into the user's source.
        let ignoredAttribute = AttributeSyntax(
            leadingTrivia: varDecl.leadingTrivia,
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier("EquatableIgnored")),
            trailingTrivia: .space
        )
        let remainingAttributes = varDecl.attributes.filter { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text != "_EquatableCheck"
        }
        var fixedDecl = varDecl.with(\.attributes, AttributeListSyntax(remainingAttributes))
        fixedDecl = fixedDecl.with(\.leadingTrivia, [])
        fixedDecl.attributes = [.attribute(ignoredAttribute)] + fixedDecl.attributes

        context.diagnose(Diagnostic(
            node: anchor,
            message: MacroExpansionErrorMessage(message),
            fixIt: .replace(
                message: SimpleFixItMessage(
                    message: "Mark '\(identifier)' with @EquatableIgnored to exclude it from the equality comparison",
                    fixItID: MessageID(domain: "EquatableMacros", id: "equatableIgnored")
                ),
                oldNode: varDecl,
                newNode: fixedDecl
            )
        ))
        return []
    }
}
