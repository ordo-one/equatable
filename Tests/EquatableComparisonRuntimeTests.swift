import Equatable
import Testing

private final class ComparisonDocument {
    let identifier: Int
    let title: String

    init(_ identifier: Int, title: String = "") {
        self.identifier = identifier
        self.title = title
    }
}

private enum LowercasedString: EquatableComparisonStrategy {
    static func comparisonValue(for value: String) -> String {
        value.lowercased()
    }
}

@Equatable
private struct ProjectedDocument: Hashable {
    @EquatableCompared(by: \ComparisonDocument.identifier)
    var document: ComparisonDocument
}

@Equatable
private struct NormalizedName: Hashable {
    @EquatableCompared(using: LowercasedString.self)
    var name: String
}

@Equatable
private struct IdentityDocument: Hashable {
    @EquatableCompared(.identity)
    var document: ComparisonDocument
}

@Equatable
private struct OptionalIdentityDocument: Hashable {
    @EquatableCompared(.identity)
    var document: ComparisonDocument?
}

private struct ComparisonKey: Equatable {
    let value: Int
}

private struct KeySource {
    let key: ComparisonKey
}

@Equatable
private struct EquatableOnlyProjection {
    @EquatableCompared(by: \KeySource.key)
    var source: KeySource
}

private struct DocumentContainer {
    var document: ComparisonDocument?
}

@Equatable
private struct OptionalNestedProjection: Hashable {
    @EquatableCompared(by: \DocumentContainer.document?.identifier)
    var container: DocumentContainer
}

@Equatable
private struct ObservedProjection: Hashable {
    @EquatableCompared(by: \ComparisonDocument.identifier)
    var `default`: ComparisonDocument {
        didSet {}
    }
}

private enum OptionalStrategy: EquatableComparisonStrategy {
    static func comparisonValue(for value: String?) -> String {
        value?.lowercased() ?? ""
    }
}

@Equatable
private struct OptionalNormalizedName: Hashable {
    @EquatableCompared(using: OptionalStrategy.self)
    var name: String?
}

private enum GenericStrategy<Value: Equatable>: EquatableComparisonStrategy {
    static func comparisonValue(for value: Value) -> Value {
        value
    }
}

@Equatable
private struct GenericCompared<Value: Equatable> {
    @EquatableCompared(using: GenericStrategy<Value>.self)
    var value: Value
}

private enum ComparisonNamespace {
    enum Strategy: EquatableComparisonStrategy {
        static func comparisonValue(for value: String) -> String {
            value.lowercased()
        }
    }
}

@Equatable.Equatable
private struct QualifiedComparison: Hashable {
    @Equatable.EquatableCompared(using: ComparisonNamespace.Strategy.self)
    var value: String
}

@Equatable
private struct QualifiedHashableComparison: Swift.Hashable {
    @EquatableCompared(using: LowercasedString.self)
    var value: String
}

private final class ComparisonCounter {
    var calls = 0
    var value: Int {
        calls += 1
        return 1
    }
}

@Equatable
private struct ShortCircuitComparison {
    let id: Int
    @EquatableCompared(by: \ComparisonCounter.value)
    let counter: ComparisonCounter
    @EquatableIgnored let ignored: String
}

private protocol ComparisonObject: AnyObject {}
extension ComparisonDocument: ComparisonObject {}

@Equatable
private struct ExistentialIdentity: Hashable {
    @EquatableCompared(EquatableComparison.identity)
    var object: (any ComparisonObject)?
}

private enum EqualityStrategy: EquatableComparisonStrategy {
    static func comparisonValue(for value: String) -> String {
        value.lowercased()
    }
}

private enum HashStrategy: EquatableComparisonStrategy {
    static func comparisonValue(for value: String) -> String {
        value.lowercased()
    }
}

@Equatable
private struct ShadowingEqualityStrategy: Hashable {
    @EquatableCompared(using: EqualityStrategy.self)
    var value: String
}

@Equatable
private struct ShadowingHashStrategy: Hashable {
    @EquatableCompared(using: HashStrategy.self)
    var value: String
}

@Equatable
private struct IdentityHashing: Hashable {
    @EquatableCompared(.identity)
    var object: ComparisonDocument?
}

@Equatable
private struct ShadowingHashParameter: Hashable {
    @EquatableCompared(using: LowercasedString.self)
    var hasher: String
}

@Equatable(isolation: .isolated)
private struct InheritedIsolationComparison: Hashable {
    @EquatableCompared(using: LowercasedString.self)
    var name: String
}

#if swift(>=6.2)
    @MainActor
    @Equatable(isolation: .main)
    private struct MainActorComparison {
        @EquatableCompared(by: \ComparisonDocument.identifier)
        var document: ComparisonDocument
        @EquatableCompared(using: LowercasedString.self)
        var name: String
        @EquatableCompared(.identity)
        var owner: ComparisonDocument?
    }

    @MainActor
    @Equatable(isolation: .main)
    private struct MainActorHashComparison: @MainActor Hashable {
        @EquatableCompared(by: \ComparisonDocument.identifier)
        var document: ComparisonDocument
        @EquatableCompared(using: LowercasedString.self)
        var name: String
        @EquatableCompared(.identity)
        var owner: ComparisonDocument?
    }
#endif

@Suite
struct EquatableComparisonRuntimeTests {
    @Test
    func projectionUsesSelectedValueRatherThanObjectOrOtherFields() {
        let lhs = ProjectedDocument(document: ComparisonDocument(1, title: "Before"))
        let same = ProjectedDocument(document: ComparisonDocument(1, title: "After"))
        let other = ProjectedDocument(document: ComparisonDocument(2, title: "Before"))
        #expect(lhs == same)
        #expect(lhs != other)
        #expect(Set([lhs]).contains(same))
        #expect(!Set([lhs]).contains(other))
        #expect([lhs: "found"][same] == "found")
    }

    @Test
    func normalizationAlsoControlsHashing() {
        let lhs = NormalizedName(name: "HELLO")
        let rhs = NormalizedName(name: "hello")
        #expect(lhs == rhs)
        #expect(lhs != NormalizedName(name: "goodbye"))
        #expect(Set([lhs, rhs]).count == 1)
        #expect([lhs: 42][rhs] == 42)
    }

    @Test
    func identityDistinguishesDifferentInstancesWithIdenticalContents() {
        let document = ComparisonDocument(1)
        let lhs = IdentityDocument(document: document)
        let same = IdentityDocument(document: document)
        let other = IdentityDocument(document: ComparisonDocument(1))
        #expect(lhs == same)
        #expect(lhs != other)
        #expect(Set([lhs, same, other]).count == 2)
        #expect([lhs: true][same] == true)
    }

    @Test
    func optionalIdentityHandlesNilAndBothReferenceCases() {
        let document = ComparisonDocument(1)
        let nilValue = OptionalIdentityDocument(document: nil)
        let lhs = OptionalIdentityDocument(document: document)
        let same = OptionalIdentityDocument(document: document)
        let other = OptionalIdentityDocument(document: ComparisonDocument(1))
        #expect(nilValue == OptionalIdentityDocument(document: nil))
        #expect(lhs != nilValue)
        #expect(nilValue != lhs)
        #expect(lhs == same)
        #expect(lhs != other)
        #expect(Set([nilValue, lhs, same, other]).count == 3)
        #expect([nilValue: "nil"][OptionalIdentityDocument(document: nil)] == "nil")
    }

    @Test
    func projectedKeysNeedNotBeHashableForEquality() {
        let lhs = EquatableOnlyProjection(source: KeySource(key: ComparisonKey(value: 1)))
        let rhs = EquatableOnlyProjection(source: KeySource(key: ComparisonKey(value: 1)))
        #expect(lhs == rhs)
        #expect(lhs != EquatableOnlyProjection(source: KeySource(key: ComparisonKey(value: 2))))
    }

    @Test
    func optionalNestedPathsCompareAndHashTheirOptionalResult() {
        let lhs = OptionalNestedProjection(container: DocumentContainer(document: ComparisonDocument(1)))
        let rhs = OptionalNestedProjection(container: DocumentContainer(document: ComparisonDocument(1)))
        let empty = OptionalNestedProjection(container: DocumentContainer(document: nil))
        #expect(lhs == rhs)
        #expect(lhs != empty)
        #expect(Set([lhs, rhs, empty]).count == 2)
    }

    @Test
    func observersAndEscapedPropertyNamesParticipate() {
        var lhs = ObservedProjection(default: ComparisonDocument(1))
        let rhs = ObservedProjection(default: ComparisonDocument(1))
        #expect(lhs == rhs)
        #expect(Set([lhs]).contains(rhs))
        lhs.default = ComparisonDocument(2)
        #expect(lhs != rhs)
    }

    @Test
    func strategiesCanNormalizeOptionalInputs() {
        #expect(OptionalNormalizedName(name: nil) == OptionalNormalizedName(name: ""))
        #expect(Set([OptionalNormalizedName(name: nil), OptionalNormalizedName(name: "")]).count == 1)
        #expect(OptionalNormalizedName(name: "A") == OptionalNormalizedName(name: "a"))
    }

    @Test
    func genericStrategiesPreserveTypeArguments() {
        let lhs = GenericCompared(value: 1)
        let same = GenericCompared(value: 1)
        let different = GenericCompared(value: 2)
        #expect(lhs == same)
        #expect(lhs != different)
    }

    @Test
    func qualifiedAttributesAndStrategyTypesCompile() {
        #expect(Set([QualifiedComparison(value: "A"), QualifiedComparison(value: "a")]).count == 1)
    }

    @Test
    func qualifiedHashableUsesComparisonStrategyForHashing() {
        let lhs = QualifiedHashableComparison(value: "A")
        let rhs = QualifiedHashableComparison(value: "a")
        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }

    @Test
    func projectionsRespectShortCircuitingAndRunOncePerOperand() {
        // The counter is test instrumentation; application projections should be pure.
        let counter = ComparisonCounter()
        let lhs = ShortCircuitComparison(id: 1, counter: counter, ignored: "a")
        let different = ShortCircuitComparison(id: 2, counter: counter, ignored: "a")
        let same = ShortCircuitComparison(id: 1, counter: counter, ignored: "b")
        #expect(lhs != different)
        #expect(counter.calls == 0)
        #expect(lhs == same)
        #expect(counter.calls == 2)
    }

    @Test
    func identitySupportsClassBoundExistentials() {
        let object = ComparisonDocument(1)
        let lhs = ExistentialIdentity(object: object)
        let rhs = ExistentialIdentity(object: object)
        #expect(lhs == rhs)
        #expect(Set([lhs, rhs, ExistentialIdentity(object: nil)]).count == 2)
    }

    @Test
    func strategiesAndIdentityHashingCompile() {
        #expect(Set([ShadowingEqualityStrategy(value: "A"), ShadowingEqualityStrategy(value: "a")]).count == 1)
        #expect(Set([ShadowingHashStrategy(value: "A"), ShadowingHashStrategy(value: "a")]).count == 1)
        let document = ComparisonDocument(1)
        #expect(Set([IdentityHashing(object: document), IdentityHashing(object: document)]).count == 1)
        #expect(Set([ShadowingHashParameter(hasher: "A"), ShadowingHashParameter(hasher: "a")]).count == 1)
    }

    @Test
    func inheritedIsolationModeSupportsStrategiesAndHashing() {
        let first = InheritedIsolationComparison(name: "A")
        let second = InheritedIsolationComparison(name: "a")
        #expect(first == second)
        #expect(Set([first, second]).count == 1)
    }

    #if swift(>=6.2)
        @Test
        @MainActor
        func mainActorIsolationSupportsAllThreeModes() {
            let owner = ComparisonDocument(2)
            let lhs = MainActorComparison(document: ComparisonDocument(1), name: "HELLO", owner: owner)
            let rhs = MainActorComparison(document: ComparisonDocument(1), name: "hello", owner: owner)
            #expect(lhs == rhs)
        }

        @Test
        @MainActor
        func mainActorHashingUsesTheSameComparisonValues() {
            let owner = ComparisonDocument(2)
            let first = MainActorHashComparison(document: ComparisonDocument(1), name: "A", owner: owner)
            let second = MainActorHashComparison(document: ComparisonDocument(1), name: "a", owner: owner)
            #expect(first == second)
            #expect(Set([first, second]).count == 1)
        }
    #endif
}
