// swiftlint:disable all
import EquatableMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

extension Issue {
    @discardableResult static func record(_ failure: TestFailureSpec) -> Self {
        record(
            Comment(rawValue: failure.message),
            sourceLocation: SourceLocation(
                fileID: failure.location.fileID,
                filePath: failure.location.filePath,
                line: failure.location.line,
                column: failure.location.column
            )
        )
    }
}

let macroSpecs = [
    "Equatable": MacroSpec(type: EquatableMacro.self, conformances: ["Equatable"]),
    "EquatableIgnored": MacroSpec(type: EquatableIgnoredMacro.self),
    "EquatableIgnoredUnsafeClosure": MacroSpec(type: EquatableIgnoredUnsafeClosureMacro.self),
]

func failureHander(_ failure: TestFailureSpec) {
    Issue.record(failure)
}

@Suite
struct EquatableMacroTests {
    enum Isolation {
        case nonisolated
        case isolated
        case main
    }

#if swift(>=6.2)
    static let testArguments: [Isolation] = [
        .nonisolated,
        .isolated,
        .main
    ]
#else
    static let testArguments: [Isolation] = [
        .nonisolated,
        .isolated
    ]
#endif

    static func equatableMacro(for isolation: Isolation) -> String {
        switch isolation {
        case .nonisolated:
            return "@Equatable"
        case .isolated:
            return "@Equatable(isolation: .isolated)"
        case .main:
            return "@Equatable(isolation: .main)"
        }
    }

    @Test(arguments: testArguments)
    func idIsComparedFirst(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension Person: Equatable {
                nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.id == rhs.id && lhs.name == rhs.name && lhs.lastName == rhs.lastName && lhs.random == rhs.random
                }
            }
            """
        case .isolated:
            """
            extension Person: Equatable {
                public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.id == rhs.id && lhs.name == rhs.name && lhs.lastName == rhs.lastName && lhs.random == rhs.random
                }
            }
            """
        case .main:
            """
            extension Person: @MainActor Equatable {
                public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.id == rhs.id && lhs.name == rhs.name && lhs.lastName == rhs.lastName && lhs.random == rhs.random
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }
            """,
            expandedSource:
            """
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func basicTypesComparedBeforeComplex(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension A: Equatable {
                nonisolated public static func == (lhs: A, rhs: A) -> Bool {
                    lhs.basicInt == rhs.basicInt && lhs.basicString == rhs.basicString && lhs.array == rhs.array && lhs.nestedType == rhs.nestedType
                }
            }
            """
        case .isolated:
            """
            extension A: Equatable {
                public static func == (lhs: A, rhs: A) -> Bool {
                    lhs.basicInt == rhs.basicInt && lhs.basicString == rhs.basicString && lhs.array == rhs.array && lhs.nestedType == rhs.nestedType
                }
            }
            """
        case .main:
            """
            extension A: @MainActor Equatable {
                public static func == (lhs: A, rhs: A) -> Bool {
                    lhs.basicInt == rhs.basicInt && lhs.basicString == rhs.basicString && lhs.array == rhs.array && lhs.nestedType == rhs.nestedType
                }
            }
            """
        }
        assertMacroExpansion(
            """
            struct NestedType: Equatable {
                let nestedInt: Int
            }
            \(macro)
            struct A {
                let nestedType: NestedType
                let array: [Int]
                let basicInt: Int
                let basicString: String
            }
            """,
            expandedSource:
            """
            struct NestedType: Equatable {
                let nestedInt: Int
            }
            struct A {
                let nestedType: NestedType
                let array: [Int]
                let basicInt: Int
                let basicString: String
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func swiftUIWrappedPropertiesSkipped(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension TitleView: Equatable {
                nonisolated public static func == (lhs: TitleView, rhs: TitleView) -> Bool {
                    lhs.title == rhs.title
                }
            }
            """
        case .isolated:
            """
            extension TitleView: Equatable {
                public static func == (lhs: TitleView, rhs: TitleView) -> Bool {
                    lhs.title == rhs.title
                }
            }
            """
        case .main:
            """
            extension TitleView: @MainActor Equatable {
                public static func == (lhs: TitleView, rhs: TitleView) -> Bool {
                    lhs.title == rhs.title
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct TitleView: View {
                @AccessibilityFocusState var accessibilityFocusState: Bool
                @AppStorage("title") var appTitle: String = "App Title"
                @Bindable var bindable = VM()
                @Environment(\\.colorScheme) var colorScheme
                @EnvironmentObject(VM.self) var environmentObject
                @FetchRequest(sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: FetchedResults<Quake>
                @FocusState var isFocused: Bool
                @FocusedObject var focusedObject = FocusModel()
                @FocusedValue(\\.focusedValue) var focusedValue
                @GestureState private var isDetectingLongPress = false
                @NSApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @Namespace var namespace
                @ObservedObject var anotherViewModel = AnotherViewModel()
                @PhysicalMetric(from: .meters) var twoAndAHalfMeters = 2.5
                @ScaledMetric(relativeTo: .body) var scaledPadding: CGFloat = 10
                @SceneStorage("title") var title: String = "Default Title"
                @SectionedFetchRequest<String, Quake>(sectionIdentifier: \\.day, sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: SectionedFetchResults<String, Quake>
                @State var dataModel = TitleDataModel()
                @StateObject private var viewModel = TitleViewModel()
                @UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @WKApplicationDelegateAdaptor var wkApplicationDelegateAdaptor: MyAppDelegate
                @WKExtensionDelegateAdaptor private var extensionDelegate: MyExtensionDelegate
                static let staticInt: Int = 42
                let title: String

                var body: some View {
                    Text(title)
                }
            }
            """,
            expandedSource:
            """
            struct TitleView: View {
                @AccessibilityFocusState var accessibilityFocusState: Bool
                @AppStorage("title") var appTitle: String = "App Title"
                @Bindable var bindable = VM()
                @Environment(\\.colorScheme) var colorScheme
                @EnvironmentObject(VM.self) var environmentObject
                @FetchRequest(sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: FetchedResults<Quake>
                @FocusState var isFocused: Bool
                @FocusedObject var focusedObject = FocusModel()
                @FocusedValue(\\.focusedValue) var focusedValue
                @GestureState private var isDetectingLongPress = false
                @NSApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @Namespace var namespace
                @ObservedObject var anotherViewModel = AnotherViewModel()
                @PhysicalMetric(from: .meters) var twoAndAHalfMeters = 2.5
                @ScaledMetric(relativeTo: .body) var scaledPadding: CGFloat = 10
                @SceneStorage("title") var title: String = "Default Title"
                @SectionedFetchRequest<String, Quake>(sectionIdentifier: \\.day, sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: SectionedFetchResults<String, Quake>
                @State var dataModel = TitleDataModel()
                @StateObject private var viewModel = TitleViewModel()
                @UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @WKApplicationDelegateAdaptor var wkApplicationDelegateAdaptor: MyAppDelegate
                @WKExtensionDelegateAdaptor private var extensionDelegate: MyExtensionDelegate
                static let staticInt: Int = 42
                let title: String

                var body: some View {
                    Text(title)
                }
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func memberSwiftUIWrappedPropertiesSkipped(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension TitleView: Equatable {
                nonisolated public static func == (lhs: TitleView, rhs: TitleView) -> Bool {
                    lhs.title == rhs.title
                }
            }
            """
        case .isolated:
            """
            extension TitleView: Equatable {
                public static func == (lhs: TitleView, rhs: TitleView) -> Bool {
                    lhs.title == rhs.title
                }
            }
            """
        case .main:
            """
            extension TitleView: @MainActor Equatable {
                public static func == (lhs: TitleView, rhs: TitleView) -> Bool {
                    lhs.title == rhs.title
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct TitleView: View {
                @SwiftUI.AccessibilityFocusState var accessibilityFocusState: Bool
                @SwiftUI.AppStorage("title") var appTitle: String = "App Title"
                @SwiftUI.Bindable var bindable = VM()
                @SwiftUI.Environment(\\.colorScheme) var colorScheme
                @SwiftUI.EnvironmentObject(VM.self) var environmentObject
                @SwiftUI.FetchRequest(sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: FetchedResults<Quake>
                @SwiftUI.FocusState var isFocused: Bool
                @SwiftUI.FocusedObject var focusedObject = FocusModel()
                @SwiftUI.FocusedValue(\\.focusedValue) var focusedValue 
                @SwiftUI.GestureState private var isDetectingLongPress = false            
                @SwiftUI.NSApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @SwiftUI.Namespace var namespace
                @SwiftUI.ObservedObject var anotherViewModel = AnotherViewModel()
                @SwiftUI.PhysicalMetric(from: .meters) var twoAndAHalfMeters = 2.5
                @SwiftUI.ScaledMetric(relativeTo: .body) var scaledPadding: CGFloat = 10
                @SwiftUI.SceneStorage("title") var title: String = "Default Title"
                @SwiftUI.SectionedFetchRequest<String, Quake>(sectionIdentifier: \\.day, sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: SectionedFetchResults<String, Quake>
                @SwiftUI.State var dataModel = TitleDataModel()
                @SwiftUI.StateObject private var viewModel = TitleViewModel()
                @SwiftUI.UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @SwiftUI.WKApplicationDelegateAdaptor var wkApplicationDelegateAdaptor: MyAppDelegate
                @SwiftUI.WKExtensionDelegateAdaptor private var extensionDelegate: MyExtensionDelegate
                static let staticInt: Int = 42
                let title: String

                var body: some View {
                    Text(title)
                }
            }
            """,
            expandedSource:
            """
            struct TitleView: View {
                @SwiftUI.AccessibilityFocusState var accessibilityFocusState: Bool
                @SwiftUI.AppStorage("title") var appTitle: String = "App Title"
                @SwiftUI.Bindable var bindable = VM()
                @SwiftUI.Environment(\\.colorScheme) var colorScheme
                @SwiftUI.EnvironmentObject(VM.self) var environmentObject
                @SwiftUI.FetchRequest(sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: FetchedResults<Quake>
                @SwiftUI.FocusState var isFocused: Bool
                @SwiftUI.FocusedObject var focusedObject = FocusModel()
                @SwiftUI.FocusedValue(\\.focusedValue) var focusedValue 
                @SwiftUI.GestureState private var isDetectingLongPress = false            
                @SwiftUI.NSApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @SwiftUI.Namespace var namespace
                @SwiftUI.ObservedObject var anotherViewModel = AnotherViewModel()
                @SwiftUI.PhysicalMetric(from: .meters) var twoAndAHalfMeters = 2.5
                @SwiftUI.ScaledMetric(relativeTo: .body) var scaledPadding: CGFloat = 10
                @SwiftUI.SceneStorage("title") var title: String = "Default Title"
                @SwiftUI.SectionedFetchRequest<String, Quake>(sectionIdentifier: \\.day, sortDescriptors: [SortDescriptor(\\.time, order: .reverse)]) var quakes: SectionedFetchResults<String, Quake>
                @SwiftUI.State var dataModel = TitleDataModel()
                @SwiftUI.StateObject private var viewModel = TitleViewModel()
                @SwiftUI.UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
                @SwiftUI.WKApplicationDelegateAdaptor var wkApplicationDelegateAdaptor: MyAppDelegate
                @SwiftUI.WKExtensionDelegateAdaptor private var extensionDelegate: MyExtensionDelegate
                static let staticInt: Int = 42
                let title: String

                var body: some View {
                    Text(title)
                }
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func markedWithEquatableIgnoredSkipped(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension BandView: Equatable {
                nonisolated public static func == (lhs: BandView, rhs: BandView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        case .isolated:
            """
            extension BandView: Equatable {
                public static func == (lhs: BandView, rhs: BandView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        case .main:
            """
            extension BandView: @MainActor Equatable {
                public static func == (lhs: BandView, rhs: BandView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct BandView: View {
                @EquatableIgnored let year: Int
                let name: String

                var body: some View {
                    Text(name)
                        .onTapGesture {
                            onTap()
                        }
                }
            }
            """,
            expandedSource:
            """
            struct BandView: View {
                let year: Int
                let name: String

                var body: some View {
                    Text(name)
                        .onTapGesture {
                            onTap()
                        }
                }
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func equatableIgnoredCannotBeAppliedToClosures() async throws {
        assertMacroExpansion(
            """
            struct CustomView: View {
                @EquatableIgnored var closure: (() -> Void)?
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """,
            expandedSource:
            """
            struct CustomView: View {
                var closure: (() -> Void)?
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@EquatableIgnored cannot be applied to closures",
                    line: 2,
                    column: 5
                )
            ],
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func equatableIgnoredCannotBeAppliedToBindings() async throws {
        assertMacroExpansion(
            """
            @Equatable
            struct CustomView: View {
                @EquatableIgnored @Binding var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """,
            expandedSource:
            """
            struct CustomView: View {
                @Binding var name: String

                var body: some View {
                    Text("CustomView")
                }
            }

            extension CustomView: Equatable {
                nonisolated public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    true
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@EquatableIgnored cannot be applied to @Binding properties",
                    line: 3,
                    column: 5
                )
            ],
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func equatableIgnoredCannotBeAppliedToFocusedBindings() async throws {
        assertMacroExpansion(
            """
            @Equatable
            struct CustomView: View {
                @EquatableIgnored @FocusedBinding(\\.focusedBinding) var focusedBinding

                var body: some View {
                    Text("CustomView")
                }
            }
            """,
            expandedSource:
            """
            struct CustomView: View {
                @FocusedBinding(\\.focusedBinding) var focusedBinding

                var body: some View {
                    Text("CustomView")
                }
            }

            extension CustomView: Equatable {
                nonisolated public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    true
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@EquatableIgnored cannot be applied to @FocusedBinding properties",
                    line: 3,
                    column: 5
                )
            ],
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func arbitaryClosuresNotAllowed(isolation: Isolation) async throws {
        // There is a bug in assertMacro somewhere and it produces the fixit with
        //
        //        @Equatable
        //        struct CustomView: View {
        //            var name: String @EquatableIgnoredUnsafeClosure
        //            let closure: (() -> Void)?
        //
        //            var body: some View {
        //                Text("CustomView")
        //            }
        //        }
        // In reality the fix it works as expected and adds a \n between the @EquatableIgnoredUnsafeClosure and name variable.
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension CustomView: Equatable {
                nonisolated public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        case .isolated:
            """
            extension CustomView: Equatable {
                public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        case .main:
            """
            extension CustomView: @MainActor Equatable {
                public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct CustomView: View {
                var name: String
                let closure: (() -> Void)?

                var body: some View {
                    Text("CustomView")
                }
            }
            """,
            expandedSource:
            """
            struct CustomView: View {
                var name: String
                let closure: (() -> Void)?

                var body: some View {
                    Text("CustomView")
                }
            }

            \(generatedConformance)
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "Arbitary closures are not supported in @Equatable",
                    line: 4,
                    column: 5,
                    fixIts: [
                        FixItSpec(message: "Consider marking the closure with@EquatableIgnoredUnsafeClosure if it doesn't effect the view's body output.")
                    ]
                )
            ],
            macroSpecs: macroSpecs,
            fixedSource:
            """
            \(macro)
            struct CustomView: View {
                var name: String @EquatableIgnoredUnsafeClosure
                let closure: (() -> Void)?

                var body: some View {
                    Text("CustomView")
                }
            }
            """,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func closuresMarkedWithEquatableIgnoredUnsafeClosure(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension CustomView: Equatable {
                nonisolated public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        case .isolated:
            """
            extension CustomView: Equatable {
                public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        case .main:
            """
            extension CustomView: @MainActor Equatable {
                public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct CustomView: View {
                @EquatableIgnoredUnsafeClosure let closure: (() -> Void)?
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """,
            expandedSource:
            """
            struct CustomView: View {
                let closure: (() -> Void)?
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func noEquatableProperties(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension NoProperties: Equatable {
                nonisolated public static func == (lhs: NoProperties, rhs: NoProperties) -> Bool {
                    true
                }
            }
            """
        case .isolated:
            """
            extension NoProperties: Equatable {
                public static func == (lhs: NoProperties, rhs: NoProperties) -> Bool {
                    true
                }
            }
            """
        case .main:
            """
            extension NoProperties: @MainActor Equatable {
                public static func == (lhs: NoProperties, rhs: NoProperties) -> Bool {
                    true
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct NoProperties: View {
                @EquatableIgnoredUnsafeClosure let onTap: () -> Void

                var body: some View {
                    Text("")
                }
            }
            """,
            expandedSource:
            """
            struct NoProperties: View {
                let onTap: () -> Void

                var body: some View {
                    Text("")
                }
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func noEquatablePropertiesConformingToHashable(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformances = switch isolation {
        case .nonisolated:
            """
            extension NoProperties: Equatable {
                nonisolated public static func == (lhs: NoProperties, rhs: NoProperties) -> Bool {
                    true
                }
            }

            extension NoProperties {
                nonisolated public func hash(into hasher: inout Hasher) {
                }
            }
            """
        case .isolated:
            """
            extension NoProperties: Equatable {
                public static func == (lhs: NoProperties, rhs: NoProperties) -> Bool {
                    true
                }
            }

            extension NoProperties {
                public func hash(into hasher: inout Hasher) {
                }
            }
            """
        case .main:
            """
            extension NoProperties: @MainActor Equatable {
                public static func == (lhs: NoProperties, rhs: NoProperties) -> Bool {
                    true
                }
            }

            extension NoProperties {
                public func hash(into hasher: inout Hasher) {
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct NoProperties: View, Hashable {
                @EquatableIgnoredUnsafeClosure let onTap: () -> Void

                var body: some View {
                    Text("")
                }
            }
            """,
            expandedSource:
            """
            struct NoProperties: View, Hashable {
                let onTap: () -> Void

                var body: some View {
                    Text("")
                }
            }

            \(generatedConformances)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func equatableMacro(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension ContentView: Equatable {
                nonisolated public static func == (lhs: ContentView, rhs: ContentView) -> Bool {
                    lhs.id == rhs.id && lhs.hour == rhs.hour && lhs.name == rhs.name && lhs.customType == rhs.customType && lhs.color == rhs.color
                }
            }
            """
        case .isolated:
            """
            extension ContentView: Equatable {
                public static func == (lhs: ContentView, rhs: ContentView) -> Bool {
                    lhs.id == rhs.id && lhs.hour == rhs.hour && lhs.name == rhs.name && lhs.customType == rhs.customType && lhs.color == rhs.color
                }
            }
            """
        case .main:
            """
            extension ContentView: @MainActor Equatable {
                public static func == (lhs: ContentView, rhs: ContentView) -> Bool {
                    lhs.id == rhs.id && lhs.hour == rhs.hour && lhs.name == rhs.name && lhs.customType == rhs.customType && lhs.color == rhs.color
                }
            }
            """
        }
        assertMacroExpansion(
            """
            struct CustomType: Equatable {
                let name: String
                let lastName: String
                let id: UUID
            }

            class ClassType {}

            extension ClassType: Equatable {
                static func == (lhs: ClassType, rhs: ClassType) -> Bool {
                    lhs === rhs
                }
            }

            \(macro)
            struct ContentView: View {
                @State private var count = 0
                let customType: CustomType
                let name: String
                let color: Color
                let id: String
                let hour: Int = 21
                @EquatableIgnored let classType: ClassType
                @EquatableIgnoredUnsafeClosure let onTapOptional: (() -> Void)?
                @EquatableIgnoredUnsafeClosure let onTap: () -> Void


                var body: some View {
                    VStack {
                        Text("Hello!")
                            .foregroundColor(color)
                            .onTapGesture {
                                onTapOptional?()
                            }
                    }
                }
            }
            """,
            expandedSource:
            """
            struct CustomType: Equatable {
                let name: String
                let lastName: String
                let id: UUID
            }

            class ClassType {}

            extension ClassType: Equatable {
                static func == (lhs: ClassType, rhs: ClassType) -> Bool {
                    lhs === rhs
                }
            }
            struct ContentView: View {
                @State private var count = 0
                let customType: CustomType
                let name: String
                let color: Color
                let id: String
                let hour: Int = 21
                let classType: ClassType
                let onTapOptional: (() -> Void)?
                let onTap: () -> Void


                var body: some View {
                    VStack {
                        Text("Hello!")
                            .foregroundColor(color)
                            .onTapGesture {
                                onTapOptional?()
                            }
                    }
                }
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func cannotBeAppliedToNonStruct() async throws {
        assertMacroExpansion(
            """
            @Equatable
            class NotAStruct {
                let name: String
            }
            """,
            expandedSource:
            """
            class NotAStruct {
                let name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Equatable can only be applied to structs",
                    line: 1,
                    column: 1
                )
            ],
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func arrayProperties(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension Person: Equatable {
                nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.name == rhs.name && lhs.first == rhs.first && lhs.second == rhs.second && lhs.third == rhs.third && lhs.nestedType == rhs.nestedType
                }
            }
            """
        case .isolated:
            """
            extension Person: Equatable {
                public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.name == rhs.name && lhs.first == rhs.first && lhs.second == rhs.second && lhs.third == rhs.third && lhs.nestedType == rhs.nestedType
                }
            }
            """
        case .main:
            """
            extension Person: @MainActor Equatable {
                public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.name == rhs.name && lhs.first == rhs.first && lhs.second == rhs.second && lhs.third == rhs.third && lhs.nestedType == rhs.nestedType
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct Person {
                struct NestedType: Equatable {
                    let nestedInt: Int
                }
                let name: String
                let first: [Int]
                let second: Array<Int>
                let third: Swift.Array<Int>
                let nestedType: NestedType
            }
            """,
            expandedSource:
            """
            struct Person {
                struct NestedType: Equatable {
                    let nestedInt: Int
                }
                let name: String
                let first: [Int]
                let second: Array<Int>
                let third: Swift.Array<Int>
                let nestedType: NestedType
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func dictionaryProperties(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformance = switch isolation {
        case .nonisolated:
            """
            extension Person: Equatable {
                nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.name == rhs.name && lhs.first == rhs.first && lhs.second == rhs.second && lhs.third == rhs.third && lhs.nestedType == rhs.nestedType
                }
            }
            """
        case .isolated:
            """
            extension Person: Equatable {
                public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.name == rhs.name && lhs.first == rhs.first && lhs.second == rhs.second && lhs.third == rhs.third && lhs.nestedType == rhs.nestedType
                }
            }
            """
        case .main:
            """
            extension Person: @MainActor Equatable {
                public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.name == rhs.name && lhs.first == rhs.first && lhs.second == rhs.second && lhs.third == rhs.third && lhs.nestedType == rhs.nestedType
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct Person {
                struct NestedType: Equatable {
                    let nestedInt: Int
                }
                let name: String
                let first: [Int:Int]
                let second: Dictionary<Int, Int>
                let third: Swift.Dictionary<Int, Int>
                let nestedType: NestedType
            }
            """,
            expandedSource:
            """
            struct Person {
                struct NestedType: Equatable {
                    let nestedInt: Int
                }
                let name: String
                let first: [Int:Int]
                let second: Dictionary<Int, Int>
                let third: Swift.Dictionary<Int, Int>
                let nestedType: NestedType
            }

            \(generatedConformance)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test(arguments: testArguments)
    func generateHashableConformanceWhenTypesConformsToHashable(isolation: Isolation) async throws {
        let macro = EquatableMacroTests.equatableMacro(for: isolation)
        let generatedConformances = switch isolation {
        case .nonisolated:
            """
            extension User: Equatable {
                nonisolated public static func == (lhs: User, rhs: User) -> Bool {
                    lhs.id == rhs.id && lhs.age == rhs.age && lhs.name == rhs.name
                }
            }

            extension User {
                nonisolated public func hash(into hasher: inout Hasher) {
                    hasher.combine(id)
                    hasher.combine(age)
                    hasher.combine(name)
                }
            }
            """
        case .isolated:
            """
            extension User: Equatable {
                public static func == (lhs: User, rhs: User) -> Bool {
                    lhs.id == rhs.id && lhs.age == rhs.age && lhs.name == rhs.name
                }
            }

            extension User {
                public func hash(into hasher: inout Hasher) {
                    hasher.combine(id)
                    hasher.combine(age)
                    hasher.combine(name)
                }
            }
            """
        case .main:
            """
            extension User: @MainActor Equatable {
                public static func == (lhs: User, rhs: User) -> Bool {
                    lhs.id == rhs.id && lhs.age == rhs.age && lhs.name == rhs.name
                }
            }

            extension User {
                public func hash(into hasher: inout Hasher) {
                    hasher.combine(id)
                    hasher.combine(age)
                    hasher.combine(name)
                }
            }
            """
        }
        assertMacroExpansion(
            """
            \(macro)
            struct User: Hashable {
              let id: Int
              @EquatableIgnored
              var name = ""
              @EquatableIgnoredUnsafeClosure
              var onTap: () -> Void
              var age: Int
              var name: String
            }
            """,
            expandedSource:
            """
            struct User: Hashable {
              let id: Int
              var name = ""
              var onTap: () -> Void
              var age: Int
              var name: String
            }

            \(generatedConformances)
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    #if swift(>=6.2)
        @Test
        func isolationMainActor() async throws {
            assertMacroExpansion(
                """
                @Equatable(isolation: .main)
                struct MainActorView: View {
                    let a: Int 
                    let name: String

                    var body: some View {
                        Text("MainActorView")
                    }
                }
                """,
                expandedSource:
                """
                struct MainActorView: View {
                    let a: Int 
                    let name: String

                    var body: some View {
                        Text("MainActorView")
                    }
                }

                extension MainActorView: @MainActor Equatable {
                    public static func == (lhs: MainActorView, rhs: MainActorView) -> Bool {
                        lhs.a == rhs.a && lhs.name == rhs.name
                    }
                }
                """,
                macroSpecs: macroSpecs,
                failureHandler: failureHander
            )
        }
    #endif
    @Test
    func isolationIsolated() async throws {
        assertMacroExpansion(
            """
            @Equatable(isolation: .isolated)
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }
            """,
            expandedSource:
            """
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }

            extension Person: Equatable {
                public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.id == rhs.id && lhs.name == rhs.name && lhs.lastName == rhs.lastName && lhs.random == rhs.random
                }
            }
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func isolationNonisolated() async throws {
        assertMacroExpansion(
            """
            @Equatable(isolation: .nonisolated)
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }
            """,
            expandedSource:
            """
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }

            extension Person: Equatable {
                nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.id == rhs.id && lhs.name == rhs.name && lhs.lastName == rhs.lastName && lhs.random == rhs.random
                }
            }
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }

    @Test
    func sameTypeComplexityPreserversOrder() async throws {
        assertMacroExpansion(
            """
            @Equatable(isolation: .nonisolated)
            struct Person {
                let first: String
                let second: String
                let third: String
            }
            """,
            expandedSource:
            """
            struct Person {
                let first: String
                let second: String
                let third: String
            }

            extension Person: Equatable {
                nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.first == rhs.first && lhs.second == rhs.second && lhs.third == rhs.third
                }
            }
            """,
            macroSpecs: macroSpecs,
            failureHandler: failureHander
        )
    }
}

// swiftlint:enable all
