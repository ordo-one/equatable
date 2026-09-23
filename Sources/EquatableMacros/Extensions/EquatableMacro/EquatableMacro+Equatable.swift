import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    // swiftlint:disable:next function_body_length
    static func generateEquatableExtensionSyntax(
        sortedProperties: [EquatableProperty],
        type: TypeSyntaxProtocol,
        isolation: Isolation
    ) -> ExtensionDeclSyntax? {
        guard !sortedProperties.isEmpty else {
            let extensionDecl: DeclSyntax = switch isolation {
            case .nonisolated:
                """
                extension \(type): Equatable {
                    nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
                        true
                    }
                }
                """
            case .isolated:
                """
                extension \(type): Equatable {
                    public static func == (lhs: Self, rhs: Self) -> Bool {
                        true
                    }
                }
                """
            case .main:
                """
                extension \(type): @MainActor Equatable {
                    public static func == (lhs: Self, rhs: Self) -> Bool {
                        true
                    }
                }
                """
            }

            return extensionDecl.as(ExtensionDeclSyntax.self)
        }

        let comparisons = sortedProperties.map(\.equalityExpression).joined(separator: " && ")

        let declarations = sortedProperties.compactMap(\.strategyDeclaration)
        let equalityImplementation = declarations.isEmpty
            ? comparisons
            : (declarations + ["return \(comparisons)"]).joined(separator: "\n")

        let extensionDecl: DeclSyntax = switch isolation {
        case .nonisolated:
            """
            extension \(type): Equatable {
                nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
                    \(raw: equalityImplementation)
                }
            }
            """
        case .isolated:
            """
            extension \(type): Equatable {
                public static func == (lhs: Self, rhs: Self) -> Bool {
                    \(raw: equalityImplementation)
                }
            }
            """
        case .main:
            """
            extension \(type): @MainActor Equatable {
                public static func == (lhs: Self, rhs: Self) -> Bool {
                    \(raw: equalityImplementation)
                }
            }
            """
        }

        return extensionDecl.as(ExtensionDeclSyntax.self)
    }
}
