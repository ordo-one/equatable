import SwiftSyntax

extension VariableDeclSyntax {
    var isStatic: Bool {
        self.modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static)
        }
    }
}
