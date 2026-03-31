import SwiftSyntax
import SwiftSyntaxMacros

public struct FormLabelMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var forId = ""

        for arg in node.arguments {
            if arg.label?.text == "for" {
                forId = extractString(from: arg.expression) ?? ""
            }
        }

        guard let body = node.trailingClosure else {
            throw MacroError("FormLabel requires a trailing closure")
        }

        let classes = "text-xs font-medium text-zinc-400 block"
        let attrs = forId.isEmpty
            ? ".class(\"\(classes)\")"
            : ".for(\"\(forId)\"), .class(\"\(classes)\")"

        return """
        label(\(raw: attrs)) {
        \(body.statements)
        }
        """
    }
}
