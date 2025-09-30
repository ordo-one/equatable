import SwiftSyntax

extension StructDeclSyntax {
    var isHashable: Bool {
        let existingConformances = inheritanceClause?.inheritedTypes
            .compactMap { $0.type.as(IdentifierTypeSyntax.self)?.name.text }
            ?? []
        return existingConformances.contains("Hashable")
    }
}
