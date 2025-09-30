[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fordo-one%2Fequatable%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ordo-one/equatable)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fordo-one%2Fequatable%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ordo-one/equatable)

[![codecov](https://codecov.io/github/ordo-one/equatable/graph/badge.svg?token=pqcp4akVCV)](https://codecov.io/github/ordo-one/equatable)

# Equatable Macros

A Swift package that provides macros for generating `Equatable` conformances for structs.

## Why Use Equatable Macros?

SwiftUI’s performance hinges on efficient view diffing—but the default behavior often falls short, especially with closures and complex view models. Manually writing Equatable conformances is tedious and error-prone.

Equatable Macros solve this by generating optimized Equatable implementations for your SwiftUI views, ensuring accurate and performant diffing out of the box. They eliminate boilerplate, prevent regressions, and help you avoid unnecessary re-renders—boosting UI performance while keeping your codebase clean and maintainable.

Ideal for teams scaling SwiftUI in large apps.

## Overview

The `@Equatable` macro generates an `Equatable` implementation that compares all of the struct's stored instance properties, excluding properties with SwiftUI property wrappers like @State and @Environment that trigger view updates through other mechanisms. Properties that aren't `Equatable` and don't affect the output of the view body can be marked with `@EquatableIgnored` to exclude them from the generated implementation. Closures are not permitted by default but can be marked with `@EquatableIgnoredUnsafeClosure` to indicate that they are safe to exclude from equality checks.

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
import Equatable
import SwiftUI

@Equatable
struct ProfileView: View {
    var username: String   // Will be compared
    @State private var isLoading = false           // Automatically skipped
    @ObservedObject var viewModel: ProfileViewModel // Automatically skipped
    @EquatableIgnored var cachedValue: String? // This property will be excluded
    @EquatableIgnoredUnsafeClosure var onTap: () -> Void // This closure is safe and will be ignored in comparison (in order for it to be safe we must be sure that this closure does not capture value types on call site)
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

 ## Isolation
`Equatable` macro supports generating the conformance with different isolation levels by using the `isolation` parameter.
The parameter accepts three values: `.nonisolated` (default), `.isolated`, and `.main` (requires Swift 6.2 or later).
The chosen isolation level will be applied to the generated conformances for both `Equatable` and `Hashable` (if applicable).

### Nonisolated (default)
The generated `Equatable` conformance is `nonisolated`, meaning it can be called from any context without isolation guarantees.
```swift
@Equatable(isolation: .nonisolated) (also omitting the parameter uses this mode)
struct Person {
    let name: String
    let age: Int
}
```

expands to:
```swift
extension Person: Equatable {
  nonisolated public static func == (lhs: Person, rhs: Person) -> Bool {
    lhs.name == rhs.name && lhs.age == rhs.age
  }
}
```

### Isolated
The generated `Equatable` conformance is `isolated`, meaning it can only be called from within the actor's context.
```swift
@Equatable(isolation: .isolated)
struct Person {
    let name: String
    let age: Int
}
```

expands to:
```swift
extension Person: Equatable {
  public static func == (lhs: Person, rhs: Person) -> Bool {
    lhs.name == rhs.name && lhs.age == rhs.age
  }
}
```

### Main (requires Swift 6.2 or later)
A common case is to have a `@MainActor` isolated type, SwiftUI views being a common example. Previously, the generated `Equatable` conformance had to be `nonisolated` in order to satisfy the protocol requirement.
This would then restrict us to access only nonisolated properties of the type in the generated `Equatable` function — which meant that we had to ignore all `@MainActor` isolated properties in the equality comparison.
Swift 6.2 introduced [isolated conformances](https://docs.swift.org/compiler/documentation/diagnostics/isolated-conformances/) allowing us to generate `Equatable` conformances
which are bound to the `@MainActor`. In this way the generated `Equatable` conformance can access `@MainActor` isolated properties of the type synchronously and the compiler will guarantee that the conformance
will be called only from the `@MainActor` context.

We can do so by specifying `@Equatable(isolation: .main)`, e.g:
```swift
@Equatable(isolation: .main)
@MainActor
struct Person {
    let name: String
    let age: Int
}
```

expands to:
```swift
extension Person: @MainActor Equatable {
    public static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.name == rhs.name && lhs.age == rhs.age
    }
}
```

## Safety Considerations

Closures marked with `@EquatableIgnoredUnsafeClosure` should not affect the logical identity of the type. For example:

### Example - Safe Usage of `@EquatableIgnoredUnsafeClosure`
```swift
struct UserActions: Equatable {
    let id: UUID
    let name: String
    @EquatableIgnoredUnsafeClosure
    var onTap: () -> Void
}
struct ContentView: View {
    var body: some View {
        UserActions(id: UUID(), name: "Example") {
            print("User tapped") // This closure does not capture value types on call site
                                // and does not influence rendering of `UserActions` view's body.
        }
    }
}
```
In this example, `onTap` will be excluded from equality comparisons, allowing the `UserActions` instances to be properly compared based only on `id` and `name`.

### Example - Unsafe Usage of `@EquatableIgnoredUnsafeClosure`
```swift
struct DemoView: View {
    @State var enabled = false
    var body: some View {
        Text("Enabled? \(enabled)")
        .onTapGesture(perform: {
            enabled.toggle()
        })
        Content(enabled: enabled)
    }
}
struct Content: View {
    var enabled: Bool
    var body: some View {
        ViewTakesClosure(
        label: "This view takes a closure",
        onTapGesture: {
            // This will always print "enabled? False", because this `ViewTakesClosure`
            // is never re-rendered (its Equatable inputs never change).
            // The closure captures the initial value of `enabled=false`.
            print("enabled? \(enabled)")
        })
    }
}
@Equatable
struct ViewTakesClosure: View {
    let label: String
    @EquatableIgnoredUnsafeClosure let onTapGesture: () -> Void
    var body: some View {
        Text(label)
        .onTapGesture(perform: onTapGesture)
    }
}
```
In this example `ViewTakesClosure`'s closure captures the `enabled` value on callsite and since it's marked with `@EquatableIgnoredUnsafeClosure`
it will not cause a re-render when the value of `enabled` changes. The closure will always print the initial value of `enabled` which is an incorrect behavior.

## Hashable conformance

If the type is marked as conforming to `Hashable` the compiler synthesized `Hashable` implementation will not be correct. That's why the `@Equatable` macro will also generate a `Hashable` implementation for the type that is aligned with the `Equatable` implementation.

```swift
import Equatable
@Equatable
struct User: Hashable {

    let id: Int
    @EquatableIgnored var name = ""
}
```

Expanded:
```swift
extension User: Equatable {
    nonisolated public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
extension User {
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

## References
This package is inspired by Cal Stephen's & Miguel Jimenez's blog post [Understanding and Improving SwiftUI Performance](https://medium.com/airbnb-engineering/understanding-and-improving-swiftui-performance-37b77ac61896).
