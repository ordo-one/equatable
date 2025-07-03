# Equatable Macros

A Swift package that provides macros for generating `Equatable` conformances for structs.

## Overview

The @Equatable macro generates an `Equatable` implementation that compares all of the struct's stored instance properties, excluding properties with SwiftUI property wrappers like @State and @Environment that trigger view updates through other mechanisms. Properties that aren't `Equatable` and don't affect the output of the view body can be marked with `@EquatableIgnored` to exclude them from the generated implementation. Closures are not permitted by default but can be marked with `@EquatableSafeClosure` to indicate that they are safe to exclude from equality checks.

## Installation

Add this package to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/ordo-one/equatable.git", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Equatable", package: "equatable")
    ]
)
```

## Usage

Apply the `@Equatable` macro to structs to automatically generate `Equatable` conformance:

```swift
@Equatable
struct ProfileView: View {
    var username: String   // Will be compared
    @State private var isLoading = false           // Automatically skipped
    @ObservedObject var viewModel: ProfileViewModel // Automatically skipped
    @EquatableIgnored var cachedValue: String? // This property will be excluded
    @EquatableSafeClosure var onTap: () -> Void // This closure is safe and will be ignored in comparison
    let id: UUID // Will be compared first for short-circuiting equality checks
    
    var body: some View {
        VStack {
            Text(username)
            if isLoading {
                ProgressView()
            }
        }
    }
}
```

The generated extension will implement the `==` operator with property comparisons ordered for optimal performance (e.g., IDs and simple types first):

```swift
extension ProfileView: Equatable {
    nonisolated public static func == (lhs: ProfileView, rhs: ProfileView) -> Bool {
        lhs.id == rhs.id && lhs.username == rhs.username
    }
}
```

## Safety Considerations

Closures marked with `@EquatableSafeClosure` should not affect the logical identity of the type. For example:

```swift
@Equatable
struct ProfileButton: View {
    let title: String

    // THIS IS NOT SAFE!!!
    // The closure captures a value type which can change,
    // but the View will not be re-rendered because the closure
    // doesn't participate in equality checks because it's marked with @EquatableSafeClosure
    @EquatableSafeClosure
    var onTap: (Int) -> Void

    var body: some View {
        Button(title) {
            onTap()
        }
    }
}
```

## References

This package is inspired by Cal Stephens' blog post [Understanding and Improving SwiftUI Performance](https://medium.com/airbnb-engineering/understanding-and-improving-swiftui-performance-37b77ac61896).
