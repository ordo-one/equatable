import EquatableMacros
import MacroTesting
import Testing

@Suite(
    .macros(
        [
            "Equatable": EquatableMacro.self,
            "EquatableIgnored": EquatableIgnoredMacro.self,
            "EquatableIgnoredUnsafeClosure": EquatableIgnoredUnsafeClosureMacro.self
        ],
        record: .missing
    )
)
struct EquatableMacroTests {
    @Test func idIsComparedFirst() async throws {
        assertMacro {
            """
            @Equatable
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }
            """
        } expansion: {
            """
            struct Person {
                let name: String
                let lastName: String
                let random: String
                let id: UUID
            }

            extension Person: Equatable {
                nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
                    lhs.id == rhs.id && lhs.lastName == rhs.lastName && lhs.name == rhs.name && lhs.random == rhs.random
                }
            }
            """
        }
    }

    @Test func basicTypesComparedBeforeComplex() async throws {
        assertMacro {
            """
            struct NestedType: Equatable {
                let nestedInt: Int
            }

            @Equatable
            struct A {
                let nestedType: NestedType
                let array: [Int]
                let basicInt: Int
                let basicString: String
            }
            """
        } expansion: {
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

            extension A: Equatable {
                nonisolated public static func == (lhs: A, rhs: A) -> Bool {
                    lhs.basicInt == rhs.basicInt && lhs.basicString == rhs.basicString && lhs.array == rhs.array && lhs.nestedType == rhs.nestedType
                }
            }
            """
        }
    }

    @Test func swiftUIWrappedPropertiesSkipped() async throws {
        assertMacro {
            """
            @Equatable
            struct TitleView: View {
                @State var dataModel = TitleDataModel()
                @Environment(\\.colorScheme) var colorScheme
                @StateObject private var viewModel = TitleViewModel()
                @ObservedObject var anotherViewModel = AnotherViewModel()
                @FocusState var isFocused: Bool
                @SceneStorage("title") var title: String = "Default Title"
                @AppStorage("title") var appTitle: String = "App Title"
                static let staticInt: Int = 42
                let title: String

                var body: some View {
                    Text(title)
                }
            }
            """
        } expansion: {
            """
            struct TitleView: View {
                @State var dataModel = TitleDataModel()
                @Environment(\\.colorScheme) var colorScheme
                @StateObject private var viewModel = TitleViewModel()
                @ObservedObject var anotherViewModel = AnotherViewModel()
                @FocusState var isFocused: Bool
                @SceneStorage("title") var title: String = "Default Title"
                @AppStorage("title") var appTitle: String = "App Title"
                static let staticInt: Int = 42
                let title: String

                var body: some View {
                    Text(title)
                }
            }

            extension TitleView: Equatable {
                nonisolated public static func == (lhs: TitleView, rhs: TitleView) -> Bool {
                    lhs.title == rhs.title
                }
            }
            """
        }
    }

    @Test func markedWithEquatableIgnoredSkipped() async throws {
        assertMacro {
            """
            @Equatable
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
            """
        } expansion: {
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

            extension BandView: Equatable {
                nonisolated public static func == (lhs: BandView, rhs: BandView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        }
    }

    @Test func equatableIgnoredCannotBeAppliedToClosures() async throws {
        assertMacro {
            """
            struct CustomView: View {
                @EquatableIgnored var closure: (() -> Void)?
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        } diagnostics: {
            """
            struct CustomView: View {
                @EquatableIgnored var closure: (() -> Void)?
                ┬────────────────
                ╰─ 🛑 @EquatableIgnored cannot be applied to closures
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        }
    }

    @Test func equatableIgnoredCannotBeAppliedToBindings() async throws {
        assertMacro {
            """
            @Equatable
            struct CustomView: View {
                @EquatableIgnored @Binding var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        } diagnostics: {
            """
            @Equatable
            ┬─────────
            ╰─ 🛑 @Equatable requires at least one equatable stored property.
            struct CustomView: View {
                @EquatableIgnored @Binding var name: String
                ┬────────────────
                ╰─ 🛑 @EquatableIgnored cannot be applied to @Binding properties

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        }
    }

    @Test func arbitaryClosuresNotAllowed() async throws {
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
        assertMacro {
            """
            @Equatable
            struct CustomView: View {
                var name: String
                let closure: (() -> Void)?

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        } diagnostics: {
            """
            @Equatable
            struct CustomView: View {
                var name: String
                let closure: (() -> Void)?
                ┬─────────────────────────
                ╰─ 🛑 Arbitary closures are not supported in @Equatable
                   ✏️ Consider marking the closure with @EquatableIgnoredUnsafeClosure if it doesn't effect the view's body output.

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        } fixes: {
            """
            @Equatable
            struct CustomView: View {
                var name: String @EquatableIgnoredUnsafeClosure 
                let closure: (() -> Void)?

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        } expansion: {
            """
            struct CustomView: View {
                var name: String 
                let closure: (() -> Void)?

                var body: some View {
                    Text("CustomView")
                }
            }

            extension CustomView: Equatable {
                nonisolated public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        }
    }

    @Test func closuresMarkedWithEquatableIgnoredUnsafeClosure() async throws {
        assertMacro {
            """
            @Equatable
            struct CustomView: View {
                @EquatableIgnoredUnsafeClosure let closure: (() -> Void)?
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }
            """
        } expansion: {
            """
            struct CustomView: View {
                let closure: (() -> Void)?
                var name: String

                var body: some View {
                    Text("CustomView")
                }
            }

            extension CustomView: Equatable {
                nonisolated public static func == (lhs: CustomView, rhs: CustomView) -> Bool {
                    lhs.name == rhs.name
                }
            }
            """
        }
    }

    @Test func noEquatableProperties() async throws {
        assertMacro {
            """
            @Equatable
            struct NoProperties: View {
                @EquatableIgnoredUnsafeClosure let onTap: () -> Void

                var body: some View {
                    Text("")
                }
            }
            """
        } diagnostics: {
            """
            @Equatable
            ┬─────────
            ╰─ 🛑 @Equatable requires at least one equatable stored property.
            struct NoProperties: View {
                @EquatableIgnoredUnsafeClosure let onTap: () -> Void

                var body: some View {
                    Text("")
                }
            }
            """
        } expansion: {
            ""
        }
    }

    @Test func equatableMacro() async throws {
        assertMacro {
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

            @Equatable
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
            """
        } expansion: {
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

            extension ContentView: Equatable {
                nonisolated public static func == (lhs: ContentView, rhs: ContentView) -> Bool {
                    lhs.id == rhs.id && lhs.hour == rhs.hour && lhs.name == rhs.name && lhs.color == rhs.color && lhs.customType == rhs.customType
                }
            }
            """
        }
    }

    @Test func cannotBeAppliedToNonStruct() async throws {
        assertMacro {
            """
            @Equatable
            class NotAStruct {
                let name: String
            }
            """
        } diagnostics: {
            """
            @Equatable
            ┬─────────
            ╰─ 🛑 @Equatable can only be applied to structs
            class NotAStruct {
                let name: String
            }
            """
        }
    }
}
