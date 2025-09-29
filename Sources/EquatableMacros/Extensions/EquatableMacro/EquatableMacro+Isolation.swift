import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    enum Isolation {
        case nonisolated
        case isolated
        case main

        var keyword: String {
            switch self {
            case .nonisolated: "nonisolated"
            case .isolated: ""
            case .main: "@MainActor "
            }
        }
    }

    static func extractIsolation(from node: AttributeSyntax) -> Isolation? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        for argument in arguments where argument.label?.text == "isolation" {
            if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                switch memberAccess.declName.baseName.text {
                case "isolated": return .isolated
                case "nonisolated": return .nonisolated
                #if swift(>=6.2)
                    case "main": return .main
                #endif
                default: return nil
                }
            }
        }

        return nil
    }
}
