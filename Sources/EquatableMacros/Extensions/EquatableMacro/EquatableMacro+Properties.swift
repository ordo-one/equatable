import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    /// Builds the `@_EquatableCheck` attribute for a property, or `nil` when the property's type
    /// can't be expressed as a macro argument (its comparison is then only checked by `_$isEqual`).
    /// Only properties without an `@EquatableCompared` marker are checked; see `EquatableProperty`.
    static func makeCheckAttribute(for property: EquatableProperty) -> AttributeSyntax? {
        if let type = property.type {
            guard let metatype = checkMetatypeExpression(for: type) else {
                return nil
            }
            return "@_EquatableCheck(type: \(metatype))"
        }
        if let initializer = property.initializer {
            // Tuples are compared by the tuple overloads of `_$isEqual`; there is no tuple overload of the check.
            if initializer.is(TupleExprSyntax.self) {
                return nil
            }
            return "@_EquatableCheck(value: \(initializer.trimmed))"
        }
        return nil
    }

    /// `Type.self` for the given type, parenthesised where the grammar requires it.
    static func checkMetatypeExpression(for type: TypeSyntax) -> ExprSyntax? {
        let type = type.trimmed

        // Tuples and metatypes have dedicated `_$isEqual` overloads but no overload of the check.
        if type.is(TupleTypeSyntax.self) || type.is(MetatypeTypeSyntax.self) {
            return nil
        }
        // `some P` can't be spelled as a metatype; `(some P).self` is rejected by the compiler.
        if let someOrAny = type.as(SomeOrAnyTypeSyntax.self), someOrAny.someOrAnySpecifier.tokenKind == .keyword(.some) {
            return nil
        }
        // `Bar!` is `Bar?` to the generated `==`.
        if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return "(\(implicitlyUnwrapped.wrappedType.trimmed)?).self"
        }

        let canBeFollowedByDotSelf = type.is(IdentifierTypeSyntax.self)
            || type.is(MemberTypeSyntax.self)
            || type.is(OptionalTypeSyntax.self)
            || type.is(ArrayTypeSyntax.self)
            || type.is(DictionaryTypeSyntax.self)
        if canBeFollowedByDotSelf {
            return "\(type).self"
        }
        return "(\(type)).self"
    }
}
