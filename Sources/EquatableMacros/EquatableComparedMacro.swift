import SwiftSyntax
import SwiftSyntaxMacros

public struct EquatableComparedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@EquatableCompared can only be applied to instance stored properties")
        }
        _ = try comparison(for: variable)

        // Do not walk past functions or nested unannotated types to find an
        // unrelated outer @Equatable declaration.
        let parent = context.lexicalContext.first { !$0.is(VariableDeclSyntax.self) }
        let parentAttributes: AttributeListSyntax?
        parentAttributes = parent?.as(StructDeclSyntax.self)?.attributes
        guard parentAttributes?.contains(where: { element in
            guard let attribute = element.as(AttributeSyntax.self) else { return false }
            return ["Equatable", "Equatable.Equatable"].contains(attribute.attributeName.trimmedDescription)
        }) == true else {
            throw MacroExpansionErrorMessage("@EquatableCompared requires an enclosing @Equatable struct")
        }
        return []
    }

    static func comparison(for declaration: VariableDeclSyntax) throws -> EquatableProperty.Comparison {
        let markers = attributes(in: declaration)
        guard markers.count == 1, let marker = markers.first else {
            throw MacroExpansionErrorMessage("A property can have only one @EquatableCompared marker")
        }
        guard declaration.bindings.count == 1, let binding = declaration.bindings.first,
              binding.pattern.is(IdentifierPatternSyntax.self) else {
            throw MacroExpansionErrorMessage("@EquatableCompared requires a single named property")
        }
        guard !declaration.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
        }), isStored(binding) else {
            throw MacroExpansionErrorMessage("@EquatableCompared can only be applied to instance stored properties")
        }
        let excludedNames = [
            "EquatableIgnored", "Equatable.EquatableIgnored",
            "EquatableIgnoredUnsafeClosure", "Equatable.EquatableIgnoredUnsafeClosure"
        ]
        if declaration.attributes.contains(where: { element in
            element.as(AttributeSyntax.self).map { excludedNames.contains($0.attributeName.trimmedDescription) } == true
        }) {
            throw MacroExpansionErrorMessage("@EquatableCompared cannot be combined with an equality exclusion marker")
        }
        guard !EquatableMacro.shouldSkip(declaration) else {
            throw MacroExpansionErrorMessage("@EquatableCompared cannot be applied to automatically skipped SwiftUI properties")
        }
        guard binding.typeAnnotation.map({ isClosure(type: $0.type) }) != true,
              binding.initializer?.value.is(ClosureExprSyntax.self) != true else {
            throw MacroExpansionErrorMessage("@EquatableCompared cannot be applied to closures")
        }
        return try comparison(from: marker)
    }

    private static func isStored(_ binding: PatternBindingSyntax) -> Bool {
        guard let block = binding.accessorBlock else { return true }
        guard case let .accessors(accessors) = block.accessors, !accessors.isEmpty else { return false }
        return accessors.allSatisfy {
            $0.accessorSpecifier.tokenKind == .keyword(.willSet) || $0.accessorSpecifier.tokenKind == .keyword(.didSet)
        }
    }

    static func attributes(in declaration: VariableDeclSyntax) -> [AttributeSyntax] {
        declaration.attributes.compactMap { element in
            guard let attribute = element.as(AttributeSyntax.self),
                  ["EquatableCompared", "Equatable.EquatableCompared"].contains(attribute.attributeName.trimmedDescription) else {
                return nil
            }
            return attribute
        }
    }

    static func comparison(from attribute: AttributeSyntax) throws -> EquatableProperty.Comparison {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              arguments.count == 1, let argument = arguments.first else {
            throw MacroExpansionErrorMessage("@EquatableCompared requires one comparison argument")
        }

        switch argument.label?.text {
        case "by":
            guard argument.expression.is(KeyPathExprSyntax.self) else {
                throw MacroExpansionErrorMessage("@EquatableCompared(by:) requires a key-path literal")
            }
            return .keyPath(argument.expression)
        case "using":
            guard let member = argument.expression.as(MemberAccessExprSyntax.self),
                  member.declName.baseName.text == "self", let base = member.base,
                  isTypeReference(base) else {
                throw MacroExpansionErrorMessage("@EquatableCompared(using:) requires a strategy metatype, such as Strategy.self")
            }
            return .strategy(base)
        case nil:
            guard let member = argument.expression.as(MemberAccessExprSyntax.self),
                  member.declName.baseName.text == "identity",
                  [nil, "EquatableComparison", "Equatable.EquatableComparison"].contains(member.base?.trimmedDescription) else {
                throw MacroExpansionErrorMessage("@EquatableCompared requires .identity, by: a key path, or using: a strategy")
            }
            return .identity
        default:
            throw MacroExpansionErrorMessage("@EquatableCompared requires .identity, by: a key path, or using: a strategy")
        }
    }

    private static func isTypeReference(_ expression: ExprSyntax) -> Bool {
        if expression.is(DeclReferenceExprSyntax.self) { return true }
        if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base {
            return isTypeReference(base)
        }
        if let specialization = expression.as(GenericSpecializationExprSyntax.self) {
            return isTypeReference(specialization.expression)
        }
        return false
    }
}
