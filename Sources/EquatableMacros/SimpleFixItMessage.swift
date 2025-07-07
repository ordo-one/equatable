import SwiftSyntax
import SwiftDiagnostics

struct SimpleFixItMessage: FixItMessage {
    let message: String
    let fixItID: MessageID
}
