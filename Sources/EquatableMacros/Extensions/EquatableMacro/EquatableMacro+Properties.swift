import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EquatableMacro {
    /// A stored property that takes part in the generated `==`.
    struct StoredProperty {
        let name: String
        /// The explicit type annotation, if any.
        let type: TypeSyntax?
        /// The initializer expression, used to infer the type when there is no annotation.
        let initializer: ExprSyntax?
    }

    enum MemberClassification {
        /// Not a stored instance property, or explicitly excluded (property wrappers, `@EquatableIgnored`, ...).
        case notCompared
        /// A closure property that isn't marked with `@EquatableIgnoredUnsafeClosure`.
        case closure(VariableDeclSyntax)
        case stored(StoredProperty)
    }

    /// Decides how a member of the annotated struct takes part in the generated conformance.
    /// Shared between the extension role (which generates `==`) and the member attribute role
    /// (which attaches `@_EquatableCheck`) so that both always agree on the set of properties.
    static func classify(_ member: some DeclSyntaxProtocol) -> MemberClassification {
        guard let varDecl = member.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              binding.accessorBlock == nil,
              !varDecl.isStatic,
              !shouldSkip(varDecl),
              !isMarkedWithEquatableIgnoredUnsafeClosure(varDecl)
        else {
            return .notCompared
        }

        let isClosureProperty = (binding.typeAnnotation?.type).map(isClosure) == true ||
            (binding.initializer?.value.is(ClosureExprSyntax.self) ?? false)
        if isClosureProperty {
            return .closure(varDecl)
        }

        return .stored(StoredProperty(
            name: identifier,
            type: binding.typeAnnotation?.type,
            initializer: binding.initializer?.value
        ))
    }

    /// Builds the `@_EquatableCheck` attribute for a property, or `nil` when the property's type
    /// can't be expressed as a macro argument (its comparison is then only checked by `_$isEqual`).
    static func makeCheckAttribute(for property: StoredProperty) -> AttributeSyntax? {
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
