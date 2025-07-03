@attached(extension, conformances: Equatable, names: named(==))
public macro Equatable() = #externalMacro(module: "EquatableMacros", type: "EquatableMacro")

@attached(peer)
public macro EquatableIgnored() = #externalMacro(module: "EquatableMacros", type: "EquatableIgnoredMacro")

@attached(peer)
public macro EquatableSafeClosure() = #externalMacro(module: "EquatableMacros", type: "EquatableSafeClosureMacro")
