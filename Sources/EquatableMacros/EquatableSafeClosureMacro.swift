import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// A macro that makes closure properties safely participate in `Equatable` conformance.
///
/// ## Overview
///
/// Closures aro not diffable by default and not allowed  when applying the `@Equatable` macro.
/// Apply the `@EquatableSafeClosure` attribute to closure which are safe to be excluded from equality comparisons.
///
/// ## Example
/// ```swift
///struct SomeView: View {
/// let name: String
/// let notSafeClosure: ((Int) -> Void)?
///}
///
///struct ContainerView: View {
/// var count: Int
///
/// var body: some View {
///     SomeView(name: "Example") {
///         print("\(count)") // this will always print count 1 because closure will not participate
///                           // in `SomeView` generated Equatable conformance thus is not safe to be marked with @EquatableSafeClosure
///     }
/// }
///}
///
///struct ContentView: View {
/// @State private var count = 1
///
/// var body: some View {
///    ContainerView(count: count)
///    Button("Increment") {
///        count += 1
///    }
/// }
///}
///
/// ```
/// ## Usage
///
/// Apply the `@EquatableSafeClosure` attribute to closure properties in your type:
///
/// ```swift
/// struct UserActions: Equatable {
///     let id: UUID
///     let name: String
///
///     @EquatableSafeClosure
///     var onTap: () -> Void
///
///     @EquatableSafeClosure
///     var onUpdate: () -> Bool
/// }
/// ```
///
/// In this example, `onTap` and `onUpdate` will be excluded from equality comparisons,
/// allowing the `UserActions` instances to be properly compared based only on `id` and `name`.
///
/// ## Requirements
///
/// - The decorated property must be a closure type
public struct EquatableSafeClosureMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl  = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first
        else {
            let diagnostic = Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage("@EquatableSafeClosure can only be applied to properties")
            )
            context.diagnose(diagnostic)
            return []
        }

        if let typeAnnotation = binding.typeAnnotation?.type {
            if !isClosure(type: typeAnnotation) {
                let diagnostic = Diagnostic(
                    node: node,
                    message: MacroExpansionErrorMessage("@EquatableSafeClosure can only be applied to closures")
                )
                context.diagnose(diagnostic)
                return []
            }
        }

        return []
    }
}
