import SwiftSyntax

extension IdentifierTypeSyntax {
    var isSwift: Bool {
        if name.text == "Swift" {
            return true
        }
        return false
    }

    var isArray: Bool {
        if name.text == "Array" {
            return true
        }
        return false
    }

    var isDictionary: Bool {
        if name.text == "Dictionary" {
            return true
        }
        return false
    }
}
