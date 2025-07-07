import SwiftDiagnostics
import SwiftSyntax

struct SimpleFixItMessage: FixItMessage {
    let message: String
    let fixItID: MessageID
}
