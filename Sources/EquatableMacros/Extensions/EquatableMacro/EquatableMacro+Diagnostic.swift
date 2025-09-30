import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    static func makeClosureDiagnostic(for varDecl: VariableDeclSyntax) -> Diagnostic {
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
}
