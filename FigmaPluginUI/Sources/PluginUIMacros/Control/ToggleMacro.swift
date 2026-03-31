import SwiftSyntax
import SwiftSyntaxMacros

/// Forwards to `_ToggleContent` defined in FigmaPluginUI.
public struct ToggleMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var idStr = ""
        var nameStr = ""
        var checked = false

        for arg in node.arguments {
            switch arg.label?.text {
            case "id":      idStr    = extractString(from: arg.expression) ?? ""
            case "name":    nameStr  = extractString(from: arg.expression) ?? ""
            case "checked": checked  = extractBool(from: arg.expression) ?? false
            default: break
            }
        }

        guard let body = node.trailingClosure else {
            throw MacroError("Toggle requires a trailing closure for the label")
        }

        return """
        _ToggleContent(id: "\(raw: idStr)", name: "\(raw: nameStr)", checked: \(raw: checked ? "true" : "false")) {
        \(body.statements)
        }
        """
    }
}
