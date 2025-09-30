import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    // swiftlint:disable:next function_body_length
    static func generateHashableExtensionSyntax(
        sortedProperties: [(name: String, type: TypeSyntax?)],
        type: TypeSyntaxProtocol,
        isolation: Isolation
    ) -> ExtensionDeclSyntax? {
        guard !sortedProperties.isEmpty else {
            let hashableExtensionDecl: DeclSyntax = switch isolation {
            case .nonisolated:
                """
                extension \(raw: type) {
                    nonisolated public func hash(into hasher: inout Hasher) {}
                }
                """
            case .isolated:
                """
                extension \(raw: type) {
                    public func hash(into hasher: inout Hasher) {}
                }
                """
            case .main:
                """
                extension \(raw: type) {
                    public func hash(into hasher: inout Hasher) {}
                }
                """
            }

            return hashableExtensionDecl.as(ExtensionDeclSyntax.self)
        }

        let hashableImplementation = sortedProperties.map { property in
            "hasher.combine(\(property.name))"
        }
        .joined(separator: "\n")

        let hashableExtensionDecl: DeclSyntax = switch isolation {
        case .nonisolated:
            """
            extension \(raw: type) {
                nonisolated public func hash(into hasher: inout Hasher) {
                    \(raw: hashableImplementation)
                }
            }
            """
        case .isolated:
            """
            extension \(raw: type) {
                public func hash(into hasher: inout Hasher) {
                    \(raw: hashableImplementation)
                }
            }
            """
        case .main:
            """
            extension \(raw: type) {
                public func hash(into hasher: inout Hasher) {
                    \(raw: hashableImplementation)
                }
            }
            """
        }

        return hashableExtensionDecl.as(ExtensionDeclSyntax.self)
    }
}
