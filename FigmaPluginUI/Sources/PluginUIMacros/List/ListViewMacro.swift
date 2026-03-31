import SwiftSyntax
import SwiftSyntaxMacros

public struct ListViewMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var divided = false

        for arg in node.arguments {
            if arg.label?.text == "divided" {
                divided = extractBool(from: arg.expression) ?? false
            }
        }

        let divideClass = divided ? " divide-y divide-zinc-700" : ""

        guard let body = node.trailingClosure else {
            throw MacroError("ListView requires a trailing closure")
        }

        return """
        ul(.class("flex flex-col\(raw: divideClass)")) {
        \(body.statements)
        }
        """
    }
}
