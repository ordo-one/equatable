import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct EquatablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EquatableMacro.self,
        EquatableIgnoredMacro.self,
        EquatableIgnoredUnsafeClosureMacro.self
    ]
}
