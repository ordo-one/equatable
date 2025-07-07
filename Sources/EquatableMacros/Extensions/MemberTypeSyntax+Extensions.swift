import SwiftSyntax

extension MemberTypeSyntax {
    var isArray: Bool {
        if self.baseType.isSwift,
           self.name.text == "Array" {
            return true
        }
        return false
    }

    var isDictionary: Bool {
        if self.baseType.isSwift,
           self.name.text == "Dictionary" {
            return true
        }
        return false
    }
}
