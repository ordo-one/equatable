import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    // swiftlint:disable:next cyclomatic_complexity
    static func typeComplexity(_ type: TypeSyntax?) -> Int {
        guard let type else { return 100 } // Unknown types go last

        let typeString = type.description.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        switch typeString {
        case "Bool": return 1
        case "Int", "Int8", "Int16", "Int32", "Int64": return 2
        case "UInt", "UInt8", "UInt16", "UInt32", "UInt64": return 3
        case "Float", "Double": return 4
        case "String": return 5
        case "Character": return 6
        case "Date": return 7
        case "Data": return 8
        case "URL": return 9
        case "UUID": return 10
        default:
            if type.is(OptionalTypeSyntax.self) {
                if let wrappedType = type.as(OptionalTypeSyntax.self)?.wrappedType {
                    return typeComplexity(wrappedType) + 20
                }
            }

            if type.isArray {
                return 30
            }

            if type.isDictionary {
                return 40
            }

            return 50
        }
    }
}
