import SwiftSyntax
import SwiftSyntaxMacros

private enum TableLayout: String {
    case auto, fixed

    var css: String {
        switch self {
        case .auto:  "table-auto"
        case .fixed: "table-fixed"
        }
    }
}

public struct TableMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var layoutStr: String?

        for arg in node.arguments {
            if arg.label?.text == "layout" {
                layoutStr = extractEnumCase(from: arg.expression)
            }
        }

        let layout  = TableLayout(rawValue: layoutStr ?? "auto") ?? .auto
        let classes = "w-full \(layout.css) border-collapse"

        guard let body = node.trailingClosure else {
            throw MacroError("Table requires a trailing closure")
        }

        return """
        table(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
