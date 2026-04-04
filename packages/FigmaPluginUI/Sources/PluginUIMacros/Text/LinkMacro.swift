import SwiftSyntax
import SwiftSyntaxMacros

public struct LinkMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var destination = "#"

        for arg in node.arguments {
            if arg.label?.text == "destination" {
                destination = extractString(from: arg.expression) ?? "#"
            }
        }

        guard let body = node.trailingClosure else {
            throw MacroError("Link requires a trailing closure")
        }

        return """
        a(.href("\(raw: destination)"), .class("text-blue-400 hover:text-blue-300 hover:underline transition-colors")) {
        \(body.statements)
        }
        """
    }
}
