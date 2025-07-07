import SwiftSyntax

extension IdentifierTypeSyntax {
    var isSwift: Bool {
        if self.name.text == "Swift" {
            return true
        }
        return false
    }

    var isArray: Bool {
        if self.name.text == "Array" {
            return true
        }
        return false
    }

    var isDictionary: Bool {
        if self.name.text == "Dictionary" {
            return true
        }
        return false
    }
}
