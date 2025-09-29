import SwiftSyntax

extension MemberTypeSyntax {
    var isArray: Bool {
        if baseType.isSwift,
           name.text == "Array" {
            return true
        }
        return false
    }

    var isDictionary: Bool {
        if baseType.isSwift,
           name.text == "Dictionary" {
            return true
        }
        return false
    }
}
