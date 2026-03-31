import SwiftSyntax
import SwiftSyntaxMacros

public struct PickerMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var idStr: String?
        var nameStr: String?

        for arg in node.arguments {
            switch arg.label?.text {
            case "id":   idStr   = extractString(from: arg.expression)
            case "name": nameStr = extractString(from: arg.expression)
            default: break
            }
        }

        let id   = idStr   ?? nameStr ?? ""
        let name = nameStr ?? idStr   ?? ""
        let idAttr = id.isEmpty ? "" : ".id(\"\(id)\"), .name(\"\(name)\"), "
        let classes = "w-full bg-zinc-800 text-zinc-200 text-sm rounded-md px-3 py-2 border border-zinc-700 focus:outline-none focus:border-zinc-500"

        guard let body = node.trailingClosure else {
            throw MacroError("Picker requires a trailing closure with option elements")
        }

        return """
        select(\(raw: idAttr).class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
