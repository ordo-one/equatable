import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The expansion of `@_EquatableCheck` when the compiler resolved the attribute to an overload whose
/// argument type is `Equatable` or a class. There is nothing to do: the property can be compared.
public struct EquatableCheckPassMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
