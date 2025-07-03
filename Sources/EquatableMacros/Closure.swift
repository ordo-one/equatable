import SwiftSyntax

func isClosure(type: TypeSyntax) -> Bool {
    if type.is(FunctionTypeSyntax.self) {
        return true
    }

    // If it's an optional closure extract the type from the tuple
    if let elementType = type.as(OptionalTypeSyntax.self)?.wrappedType.as(TupleTypeSyntax.self)?.elements.first?.type {
        return isClosure(type: elementType)
    }

    if let implicitlyUnwrappedType = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return isClosure(type: implicitlyUnwrappedType.wrappedType)
    }

    return false
}
