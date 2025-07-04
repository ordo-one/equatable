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
/// Apply the `@EquatableIgnoredUnsafeClosure` attribute to closure which are safe to be excluded from equality comparisons.
/// Only closures that do not capture value types on call site and do not influence rendering of the view's body are safe to be marked with this attribute.
///
/// ## Exammple - Safe Usage of `@EquatableIgnoredUnsafeClosure`
///
/// Apply the `@EquatableIgnoredUnsafeClosure` attribute to closure properties in your type:
///
/// ```swift
/// struct UserActions: Equatable {
///     let id: UUID
///     let name: String
///
///     @EquatableIgnoredUnsafeClosure
///     var onTap: () -> Void
/// }
///
/// struct ContentView: View {
///     var body: some View {
///         UserActions(id: UUID(), name: "Example") {
///             print("User tapped") // This closure does not capture value types on call site
///                                  // and does not influence rendering of `UserActions` view's body.
///         }
///     }
/// }
/// ```
///
/// In this example, `onTap` will be excluded from equality comparisons, allowing the `UserActions` instances to be properly compared based only on `id` and `name`.
///
/// ## Example - Unsafe Usage of `@EquatableIgnoredUnsafeClosure`
/// ```swift
/// struct DemoView: View {
///     @State var enabled = false
///
///     var body: some View {
///         Text("Enabled? \(enabled)")
///         .onTapGesture(perform: {
///             enabled.toggle()
///         })
///         Content(enabled: enabled)
///     }
/// }
///
/// struct Content: View {
///     var enabled: Bool
///     var body: some View {
///         ViewTakesClosure(
///         label: "This view takes a closure",
///         onTapGesture: {
///             // This will always print "enabled? False", because this `ViewTakesClosure`
///             // is never re-rendered (its Equatable inputs never change).
///             // The closure captures the initial value of `enabled=false`.
///             print("enabled? \(enabled)")
///         })
///     }
/// }
///
/// @Equabable
/// struct ViewTakesClosure: View {
///     let label: String
///     @EquatableIgnoredUnsafeClosure let onTapGesture: () -> Void
///
///     var body: some View {
///         Text(label)
///         .onTapGesture(perform: onTapGesture)
///     }
/// }
/// ```
///
/// In this example `ViewTakesClosure`'s closure captures the `enabled` value on callsite and since it's marked with `@EquatableIgnoredUnsafeClosure`
/// it will not cause a re-render when the value of `enabled` changes. The closure will always print the initial value of `enabled` which is an incorrect behavior.
///
/// ## Requirements
///
/// - The decorated property must be a closure type
public struct EquatableIgnoredUnsafeClosureMacro: PeerMacro {
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
                message: MacroExpansionErrorMessage("@EquatableIgnoredUnsafeClosure can only be applied to properties")
            )
            context.diagnose(diagnostic)
            return []
        }

        if let typeAnnotation = binding.typeAnnotation?.type {
            if !isClosure(type: typeAnnotation) {
                let diagnostic = Diagnostic(
                    node: node,
                    message: MacroExpansionErrorMessage("@EquatableIgnoredUnsafeClosure can only be applied to closures")
                )
                context.diagnose(diagnostic)
                return []
            }
        }

        return []
    }
}
