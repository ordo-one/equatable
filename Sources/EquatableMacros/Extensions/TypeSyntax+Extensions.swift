import SwiftSyntax

extension TypeSyntax {
    var isSwift: Bool {
        if self.as(IdentifierTypeSyntax.self)?.isSwift ?? false {
            return true
        }
        return false
    }

    var isArray: Bool {
        if self.is(ArrayTypeSyntax.self) {
            return true
        }
        if self.as(IdentifierTypeSyntax.self)?.isArray ?? false {
            return true
        }
        if self.as(MemberTypeSyntax.self)?.isArray ?? false {
            return true
        }
        return false
    }

    var isDictionary: Bool {
        if self.is(DictionaryTypeSyntax.self) {
            return true
        }
        if self.as(IdentifierTypeSyntax.self)?.isDictionary ?? false {
            return true
        }
        if self.as(MemberTypeSyntax.self)?.isDictionary ?? false {
            return true
        }
        return false
    }
}
