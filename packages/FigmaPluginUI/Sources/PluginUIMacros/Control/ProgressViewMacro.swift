import SwiftSyntax
import SwiftSyntaxMacros

public struct ProgressViewMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // percent: Int (0-100). Omit for indeterminate.
        var percent: Int? = nil

        for arg in node.arguments {
            if arg.label?.text == "percent" || arg.label?.text == "value" {
                if let intLit = arg.expression.as(IntegerLiteralExprSyntax.self),
                   let n = Int(intLit.literal.text) {
                    percent = n
                }
            }
        }

        if let pct = percent {
            // Determinate — render a styled div bar
            let width = min(max(pct, 0), 100)
            return """
            div(.class("w-full bg-zinc-700 rounded-full h-2 overflow-hidden")) {
                div(.class("bg-blue-500 h-2 rounded-full transition-all"), .custom(name: "style", value: "width:\(raw: width)%")) {}
            }
            """
        } else {
            // Indeterminate — animated pulse bar
            return """
            div(.class("w-full bg-zinc-700 rounded-full h-2 overflow-hidden")) {
                div(.class("bg-blue-500 h-2 rounded-full w-1/3 animate-pulse")) {}
            }
            """
        }
    }
}
