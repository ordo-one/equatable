import EquatableMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

private let comparisonMacroSpecs = macroSpecs.merging([
    "EquatableCompared": MacroSpec(type: EquatableComparedMacro.self)
]) { _, new in new }

@Suite
struct EquatableComparisonDiagnosticTests {
    struct Misuse: Sendable {
        let member: String
        let expanded: String
        let message: String
    }

    @Test(arguments: [
        Misuse(
            member: "@EquatableCompared(.identity) static var value: Object",
            expanded: "static var value: Object",
            message: "@EquatableCompared can only be applied to instance stored properties"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) class var value: Object { Object() }",
            expanded: "class var value: Object { Object() }",
            message: "@EquatableCompared can only be applied to instance stored properties"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) var value: Object { Object() }",
            expanded: "var value: Object { Object() }",
            message: "@EquatableCompared can only be applied to instance stored properties"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) var value: Object, other: Object",
            expanded: "var value: Object, other: Object",
            message: "peer macro can only be applied to a single variable"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) @EquatableIgnored var value: Object",
            expanded: "var value: Object",
            message: "@EquatableCompared cannot be combined with an equality exclusion marker"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) @EquatableIgnoredUnsafeClosure var value: () -> Void",
            expanded: "var value: () -> Void",
            message: "@EquatableCompared cannot be combined with an equality exclusion marker"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) @State var value: Object",
            expanded: "@State var value: Object",
            message: "@EquatableCompared cannot be applied to automatically skipped SwiftUI properties"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) @SwiftUI.State var value: Object",
            expanded: "@SwiftUI.State var value: Object",
            message: "@EquatableCompared cannot be applied to automatically skipped SwiftUI properties"
        ),
        Misuse(
            member: "@EquatableCompared(.identity) var value: () -> Void",
            expanded: "var value: () -> Void",
            message: "@EquatableCompared cannot be applied to closures"
        ),
        Misuse(
            member: "@EquatableCompared(by: path) var value: Object",
            expanded: "var value: Object",
            message: "@EquatableCompared(by:) requires a key-path literal"
        ),
        Misuse(
            member: "@EquatableCompared(using: strategy) var value: Object",
            expanded: "var value: Object",
            message: "@EquatableCompared(using:) requires a strategy metatype, such as Strategy.self"
        ),
        Misuse(
            member: "@EquatableCompared(using: makeStrategy().self) var value: Object",
            expanded: "var value: Object",
            message: "@EquatableCompared(using:) requires a strategy metatype, such as Strategy.self"
        ),
        Misuse(
            member: "@EquatableCompared(.unknown) var value: Object",
            expanded: "var value: Object",
            message: "@EquatableCompared requires .identity, by: a key path, or using: a strategy"
        ),
        Misuse(
            member: "@EquatableCompared() var value: Object",
            expanded: "var value: Object",
            message: "@EquatableCompared requires one comparison argument"
        ),
        Misuse(
            member: "@EquatableCompared(mode: .identity) var value: Object",
            expanded: "var value: Object",
            message: "@EquatableCompared requires .identity, by: a key path, or using: a strategy"
        )
    ])
    func invalidConfigurationIsDiagnosedAtTheMarker(_ misuse: Misuse) {
        assertMacroExpansion(
            """
            @Equatable
            struct Model {
                \(misuse.member)
            }
            """,
            expandedSource: """
            struct Model {
                \(misuse.expanded)
            }
            """,
            diagnostics: [DiagnosticSpec(message: misuse.message, line: 3, column: 5)],
            macroSpecs: comparisonMacroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func requiresAnEquatableParent() {
        assertMacroExpansion(
            """
            struct Model {
                @EquatableCompared(.identity) var value: Object
            }
            """,
            expandedSource: """
            struct Model {
                var value: Object
            }
            """,
            diagnostics: [DiagnosticSpec(
                message: "@EquatableCompared requires an enclosing @Equatable struct",
                line: 2, column: 5
            )],
            macroSpecs: comparisonMacroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func rejectsNonProperties() {
        assertMacroExpansion(
            """
            @EquatableCompared(.identity)
            func value() {}
            """,
            expandedSource: "func value() {}",
            diagnostics: [DiagnosticSpec(
                message: "@EquatableCompared can only be applied to instance stored properties",
                line: 1, column: 1
            )],
            macroSpecs: comparisonMacroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func rejectsDuplicateStrategies() {
        assertMacroExpansion(
            """
            @Equatable
            struct Model {
                @EquatableCompared(.identity)
                @EquatableCompared(.identity)
                var value: Object
            }
            """,
            expandedSource: """
            struct Model {
                var value: Object
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "A property can have only one @EquatableCompared marker", line: 3, column: 5),
                DiagnosticSpec(message: "A property can have only one @EquatableCompared marker", line: 4, column: 5)
            ],
            macroSpecs: comparisonMacroSpecs,
            failureHandler: failureHander
        )
    }
}
