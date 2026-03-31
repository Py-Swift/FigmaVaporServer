import SwiftSyntax
import SwiftSyntaxMacros

/// Forwards to `_AlertContent` defined in FigmaPluginUI.
public struct AlertMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var styleStr = "info"
        var titleStr = ""

        for arg in node.arguments {
            switch arg.label?.text {
            case "style": styleStr = extractEnumCase(from: arg.expression) ?? "info"
            case "title": titleStr = extractString(from: arg.expression) ?? ""
            default: break
            }
        }

        guard let body = node.trailingClosure else {
            throw MacroError("Alert requires a trailing closure for the message body")
        }

        return """
        _AlertContent(style: .\(raw: styleStr), title: "\(raw: titleStr)") {
        \(body.statements)
        }
        """
    }
}
