import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    // swiftlint:disable:next function_body_length
    static func generateEquatableExtensionSyntax(
        sortedProperties: [(name: String, type: TypeSyntax?)],
        type: TypeSyntaxProtocol,
        isolation: Isolation
    ) -> ExtensionDeclSyntax? {
        guard !sortedProperties.isEmpty else {
            let extensionDecl: DeclSyntax = switch isolation {
            case .nonisolated:
                """
                extension \(type): Equatable {
                    nonisolated public static func == (lhs: \(type), rhs: \(type)) -> Bool {
                        true
                    }
                }
                """
            case .isolated:
                """
                extension \(type): Equatable {
                    public static func == (lhs: \(type), rhs: \(type)) -> Bool {
                        true
                    }
                }
                """
            case .main:
                """
                extension \(type): @MainActor Equatable {
                    public static func == (lhs: \(type), rhs: \(type)) -> Bool {
                        true
                    }
                }
                """
            }

            return extensionDecl.as(ExtensionDeclSyntax.self)
        }

        let comparisons = sortedProperties.map { property in
            "lhs.\(property.name) == rhs.\(property.name)"
        }.joined(separator: " && ")

        let equalityImplementation = comparisons.isEmpty ? "true" : comparisons

        let extensionDecl: DeclSyntax = switch isolation {
        case .nonisolated:
            """
            extension \(type): Equatable {
                nonisolated public static func == (lhs: \(type), rhs: \(type)) -> Bool {
                    \(raw: equalityImplementation)
                }
            }
            """
        case .isolated:
            """
            extension \(type): Equatable {
                public static func == (lhs: \(type), rhs: \(type)) -> Bool {
                    \(raw: equalityImplementation)
                }
            }
            """
        case .main:
            """
            extension \(type): @MainActor Equatable {
                public static func == (lhs: \(type), rhs: \(type)) -> Bool {
                    \(raw: equalityImplementation)
                }
            }
            """
        }

        return extensionDecl.as(ExtensionDeclSyntax.self)
    }
}
