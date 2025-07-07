// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Equatable",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .macCatalyst(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Equatable",
            targets: ["Equatable"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"602.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "EquatableMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "Equatable", dependencies: ["EquatableMacros"]),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "EquatableClient", dependencies: ["Equatable"]),

        .testTarget(
            name: "EquatableTests",
            dependencies: [
                "EquatableMacros",
                .product(name: "MacroTesting", package: "swift-macro-testing")
            ]
        )
    ]
)
