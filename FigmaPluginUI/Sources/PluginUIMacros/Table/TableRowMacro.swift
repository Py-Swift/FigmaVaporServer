import SwiftSyntax
import SwiftSyntaxMacros

public struct TableRowMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let body = node.trailingClosure else {
            throw MacroError("TableRow requires a trailing closure")
        }

        return """
        tr(.class("border-b border-zinc-700")) {
        \(body.statements)
        }
        """
    }
}
