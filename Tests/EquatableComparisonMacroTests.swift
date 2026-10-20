import EquatableMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

private func strategyComparison(property: String) -> String {
    let strategy = "__macro_local_18ComparisonStrategyfMu_"
    return "\(strategy).comparisonValue(for: lhs.\(property)) == "
        + "\(strategy).comparisonValue(for: rhs.\(property))"
}

@Suite
struct EquatableComparisonMacroTests {
    @Test
    func hashExpressionsCannotBeShadowedByPropertyNames() {
        assertMacroExpansion(
            """
            @Equatable
            struct Model: Hashable {
                @EquatableCompared(using: Normalize.self) var hasher: String
                @EquatableCompared(.identity) var ObjectIdentifier: Owner?
            }
            """,
            expandedSource: """
            struct Model: Hashable {
                @EquatableCompared(using: Normalize.self) var hasher: String
                @EquatableCompared(.identity) var ObjectIdentifier: Owner?
            }

            extension Model: Equatable {
                nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
                    typealias __macro_local_18ComparisonStrategyfMu_ = Normalize
                    return \(strategyComparison(property: "hasher")) && lhs.ObjectIdentifier === rhs.ObjectIdentifier
                }
            }

            extension Model {
                nonisolated public func hash(into hasher: inout Hasher) {
                    typealias __macro_local_18ComparisonStrategyfMu_ = Normalize
                    hasher.combine(__macro_local_18ComparisonStrategyfMu_.comparisonValue(for: self.hasher))
                    hasher.combine(
                        { (object: Swift.AnyObject?) -> Swift.ObjectIdentifier? in
                            guard let object else {
                                return nil
                            }
                            return .init(object)
                        }(self.ObjectIdentifier)
                    )
                }
            }
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func qualifiedHashableUsesComparisonStrategyForHashing() {
        assertMacroExpansion(
            """
            @Equatable
            struct Model: Swift.Hashable {
                @EquatableCompared(using: Normalize.self) var name: String
            }
            """,
            expandedSource: """
            struct Model: Swift.Hashable {
                @EquatableCompared(using: Normalize.self) var name: String
            }

            extension Model: Equatable {
                nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
                    typealias __macro_local_18ComparisonStrategyfMu_ = Normalize
                    return \(strategyComparison(property: "name"))
                }
            }

            extension Model {
                nonisolated public func hash(into hasher: inout Hasher) {
                    typealias __macro_local_18ComparisonStrategyfMu_ = Normalize
                    hasher.combine(__macro_local_18ComparisonStrategyfMu_.comparisonValue(for: self.name))
                }
            }
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func projectionDrivesBothEqualityAndHashing() {
        assertMacroExpansion(
            #"""
            @Equatable
            struct Model: Hashable {
                @EquatableCompared(by: \Document.identifier)
                var document: Document
            }
            """#,
            expandedSource: #"""
            struct Model: Hashable {
                @EquatableCompared(by: \Document.identifier)
                var document: Document
            }

            extension Model: Equatable {
                nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.document[keyPath: \Document.identifier] == rhs.document[keyPath: \Document.identifier]
                }
            }

            extension Model {
                nonisolated public func hash(into hasher: inout Hasher) {
                    hasher.combine(self.document[keyPath: \Document.identifier])
                }
            }
            """#,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func identityAndStrategyDriveBothEqualityAndHashing() {
        assertMacroExpansion(
            """
            @Equatable
            struct Model: Hashable {
                @EquatableCompared(.identity) var owner: Owner?
                @EquatableCompared(using: Normalize.self) var name: String
            }
            """,
            expandedSource: """
            struct Model: Hashable {
                @EquatableCompared(.identity) var owner: Owner?
                @EquatableCompared(using: Normalize.self) var name: String
            }

            extension Model: Equatable {
                nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
                    typealias __macro_local_18ComparisonStrategyfMu_ = Normalize
                    return \(strategyComparison(property: "name")) && lhs.owner === rhs.owner
                }
            }

            extension Model {
                nonisolated public func hash(into hasher: inout Hasher) {
                    typealias __macro_local_18ComparisonStrategyfMu_ = Normalize
                    hasher.combine(__macro_local_18ComparisonStrategyfMu_.comparisonValue(for: self.name))
                    hasher.combine(
                        { (object: Swift.AnyObject?) -> Swift.ObjectIdentifier? in
                            guard let object else {
                                return nil
                            }
                            return .init(object)
                        }(self.owner)
                    )
                }
            }
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }
}
