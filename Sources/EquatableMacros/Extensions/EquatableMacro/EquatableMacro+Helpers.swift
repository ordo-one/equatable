import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    // Skip properties with SwiftUI attributes (like @State, @Binding, etc.) or if they are marked with @EqutableIgnored
    static func shouldSkip(_ varDecl: VariableDeclSyntax) -> Bool {
        varDecl.attributes.contains { attribute in
            if let atribute = attribute.as(AttributeSyntax.self),
               shouldSkip(atribute: atribute) {
                return true
            }
            return false
        }
    }

    static func shouldSkip(atribute node: AttributeSyntax) -> Bool {
        if let identifierType = node.attributeName.as(IdentifierTypeSyntax.self),
           shouldSkip(identifierType: identifierType) {
            return true
        }
        if let memberType = node.attributeName.as(MemberTypeSyntax.self),
           Self.shouldSkip(memberType: memberType) {
            return true
        }
        return false
    }

    static func shouldSkip(identifierType node: IdentifierTypeSyntax) -> Bool {
        if node.name.text == "EquatableIgnored" {
            return true
        }
        if skippablePropertyWrappers.contains(node.name.text) {
            return true
        }
        return false
    }

    static func shouldSkip(memberType node: MemberTypeSyntax) -> Bool {
        if node.baseType.as(IdentifierTypeSyntax.self)?.name.text == "SwiftUI",
           skippablePropertyWrappers.contains(node.name.text) {
            return true
        }
        return false
    }

    static func isMarkedWithEquatableIgnoredUnsafeClosure(_ varDecl: VariableDeclSyntax) -> Bool {
        varDecl.attributes.contains(where: { attribute in
            if let attributeName = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text {
                return attributeName == "EquatableIgnoredUnsafeClosure"
            }
            return false
        })
    }

    static func compare(lhs: (name: String, type: TypeSyntax?), rhs: (name: String, type: TypeSyntax?)) -> Bool {
        // "id" always comes first
        if lhs.name == "id" { return true }
        if rhs.name == "id" { return false }

        let lhsComplexity = typeComplexity(lhs.type)
        let rhsComplexity = typeComplexity(rhs.type)

        if lhsComplexity == rhsComplexity {
            return lhs.name < rhs.name
        }
        return lhsComplexity < rhsComplexity
    }
}
