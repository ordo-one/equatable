import SwiftSyntax

extension StructDeclSyntax {
    var isHashable: Bool {
        inheritanceClause?.inheritedTypes.contains { inherited in
            var type = inherited.type
            while let attributed = type.as(AttributedTypeSyntax.self) {
                type = attributed.baseType
            }
            if type.as(IdentifierTypeSyntax.self)?.name.text == "Hashable" {
                return true
            }
            guard let memberType = type.as(MemberTypeSyntax.self) else {
                return false
            }
            return memberType.baseType.trimmedDescription == "Swift" && memberType.name.text == "Hashable"
        } ?? false
    }
}
