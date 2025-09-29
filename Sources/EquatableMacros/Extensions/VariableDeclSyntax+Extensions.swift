import SwiftSyntax

extension VariableDeclSyntax {
    var isStatic: Bool {
        modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static)
        }
    }
}
