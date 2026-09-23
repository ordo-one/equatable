import SwiftSyntax
import SwiftSyntaxMacros

/// One source of truth for the components used by equality and hashing.
struct EquatableProperty {
    enum Comparison {
        case value
        case keyPath(ExprSyntax)
        case identity
        case strategy(ExprSyntax)
    }

    let name: String
    let type: TypeSyntax?
    let comparison: Comparison
    private let strategyAlias: String

    init(name: String, type: TypeSyntax?, comparison: Comparison, in context: some MacroExpansionContext) {
        self.name = name
        self.type = type
        self.comparison = comparison
        if case .strategy = comparison {
            strategyAlias = context.makeUniqueName("ComparisonStrategy").text
        } else {
            strategyAlias = ""
        }
    }

    var strategyDeclaration: String? {
        guard case let .strategy(strategy) = comparison else { return nil }
        // A type position prevents generated parameters (lhs, rhs, hasher) or
        // instance properties from shadowing the user's strategy type.
        return "typealias \(strategyAlias) = \(strategy.trimmedDescription)"
    }

    var equalityExpression: String {
        if case .identity = comparison {
            return "lhs.\(name) === rhs.\(name)"
        }
        return "\(comparisonValue(for: "lhs.\(name)")) == \(comparisonValue(for: "rhs.\(name)"))"
    }

    var hashExpression: String {
        switch comparison {
        case .value:
            // Preserve the existing expansion for unannotated properties.
            "hasher.combine(\(name))"
        case .identity:
            // Contextual optional promotion supports both optional and nonoptional
            // references without guessing the property's resolved type from syntax.
            """
            hasher.combine(
                { (object: Swift.AnyObject?) -> Swift.ObjectIdentifier? in
                    guard let object else {
                        return nil
                    }
                    return .init(object)
                }(self.\(name))
            )
            """
        case .keyPath, .strategy:
            "hasher.combine(\(comparisonValue(for: "self.\(name)")))"
        }
    }

    private func comparisonValue(for base: String) -> String {
        switch comparison {
        case .value, .identity:
            base
        case let .keyPath(path):
            "\(base)[keyPath: \(path.trimmedDescription)]"
        case .strategy:
            "\(strategyAlias).comparisonValue(for: \(base))"
        }
    }
}
