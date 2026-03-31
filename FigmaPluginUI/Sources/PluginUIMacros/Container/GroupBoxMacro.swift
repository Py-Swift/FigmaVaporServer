import SwiftSyntax
import SwiftSyntaxMacros

/// Forwards to `_GroupBoxContent` defined in FigmaPluginUI.
public struct GroupBoxMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var titleStr: String?

        for arg in node.arguments {
            if arg.label?.text == "title" || arg.label?.text == "label" {
                titleStr = extractString(from: arg.expression)
            }
        }

        guard let body = node.trailingClosure else {
            throw MacroError("GroupBox requires a trailing closure")
        }

        if let title = titleStr, !title.isEmpty {
            return """
            _GroupBoxContent(title: "\(raw: title)") {
            \(body.statements)
            }
            """
        } else {
            return """
            _GroupBoxContent {
            \(body.statements)
            }
            """
        }
    }
}
