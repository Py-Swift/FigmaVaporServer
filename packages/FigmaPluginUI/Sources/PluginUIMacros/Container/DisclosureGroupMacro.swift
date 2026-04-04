import SwiftSyntax
import SwiftSyntaxMacros

/// Forwards to `_DisclosureGroupContent` defined in FigmaPluginUI.
public struct DisclosureGroupMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var labelStr = ""
        var isExpanded = false

        for arg in node.arguments {
            switch arg.label?.text {
            case "label":      labelStr   = extractString(from: arg.expression) ?? ""
            case "isExpanded": isExpanded = extractBool(from: arg.expression) ?? false
            default: break
            }
        }

        guard let body = node.trailingClosure else {
            throw MacroError("DisclosureGroup requires a trailing closure")
        }

        return """
        _DisclosureGroupContent(label: "\(raw: labelStr)", isExpanded: \(raw: isExpanded ? "true" : "false")) {
        \(body.statements)
        }
        """
    }
}
