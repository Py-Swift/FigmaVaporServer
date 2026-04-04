import SwiftSyntax
import SwiftSyntaxMacros

public struct TextEditorMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var idStr: String?
        var nameStr: String?
        var placeholder = ""
        var rows = 5

        for arg in node.arguments {
            switch arg.label?.text {
            case "id":          idStr       = extractString(from: arg.expression)
            case "name":        nameStr     = extractString(from: arg.expression)
            case "placeholder": placeholder = extractString(from: arg.expression) ?? ""
            case "rows":
                if let intLit = arg.expression.as(IntegerLiteralExprSyntax.self),
                   let n = Int(intLit.literal.text) {
                    rows = n
                }
            default: break
            }
        }

        let id   = idStr   ?? nameStr ?? ""
        let name = nameStr ?? idStr   ?? ""
        let classes = "w-full bg-zinc-800 text-zinc-200 font-mono text-sm rounded-md p-3 border border-zinc-700 focus:outline-none focus:border-zinc-500 resize-y placeholder-zinc-600"

        var attrParts = [
            ".class(\"\(classes)\")",
            ".custom(name: \"rows\", value: \"\(rows)\")",
        ]
        if !id.isEmpty { attrParts.insert(".id(\"\(id)\"), .name(\"\(name)\")", at: 0) }
        if !placeholder.isEmpty { attrParts.append(".custom(name: \"placeholder\", value: \"\(placeholder)\")") }

        let attrsStr = attrParts.joined(separator: ",\n    ")

        return """
        textarea(
            \(raw: attrsStr)
        ) {}
        """
    }
}
