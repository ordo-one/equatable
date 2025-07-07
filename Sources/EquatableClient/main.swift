import Equatable
#if canImport(SwiftUI)
import SwiftUI

struct MyView: View {
    let int: Int

    var body: some View {
        Text("MyView with int: \(int)")
    }
}

@Equatable
struct Test {
    let name: String
    @EquatableIgnoredUnsafeClosure let closure: (() -> Void)?
}

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

@Equatable
struct Person {
    let name: String
    let lastName: String
    let random: String
    let id: UUID
    @EquatableIgnoredUnsafeClosure let closure: (() -> Void)?
}

struct NestedType: Equatable {
    let nestedInt: Int
}

@Equatable
struct Anon {
    let nestedType: NestedType
    let array: [Int]
    let basicInt: Int
    let basicString: String
}

@Observable
final class TitleDataModel {}

@Equatable
struct TitleView: View {
    @State var dataModel = TitleDataModel()
    @Environment(\.colorScheme)
    var colorScheme
    let title: String

    var body: some View {
        Text(title)
    }
}

@Equatable
struct BandView: View {
    @EquatableIgnoredUnsafeClosure let onTap: () -> Void
    let name: String

    var body: some View {
        Text(name)
            .onTapGesture {
                onTap()
            }
    }
}

final class ProfileViewModel: ObservableObject {}

@Equatable
struct ProfileView: View {
    var username: String // Will be compared
    @State private var isLoading = false // Automatically skipped
    @ObservedObject var viewModel: ProfileViewModel // Automatically skipped
    @EquatableIgnored var cachedValue: String? // This property will be excluded
    @EquatableIgnoredUnsafeClosure var onTap: () -> Void // This closure is safe and will be ignored in comparison
    let id: UUID // will be compared first for shortcircuiting equality checks
    var body: some View {
        VStack {
            Text(username)
            if isLoading {
                ProgressView()
            }
        }
    }
}

@Equatable
struct User: Hashable {
    let id: Int
    @EquatableIgnored var name = ""
}

#endif
