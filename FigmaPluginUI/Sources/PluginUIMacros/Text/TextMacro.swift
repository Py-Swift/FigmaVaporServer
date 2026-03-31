import SwiftSyntax
import SwiftSyntaxMacros

private enum TextStyle: String {
    case largeTitle, title, title2, title3
    case headline, subheadline
    case body
    case callout, footnote
    case caption, caption2

    var css: String {
        switch self {
        case .largeTitle:   "text-4xl font-bold"
        case .title:        "text-3xl font-semibold"
        case .title2:       "text-2xl font-semibold"
        case .title3:       "text-xl font-semibold"
        case .headline:     "text-base font-semibold"
        case .subheadline:  "text-sm font-medium text-zinc-400"
        case .body:         "text-base"
        case .callout:      "text-sm"
        case .footnote:     "text-xs text-zinc-400"
        case .caption:      "text-xs text-zinc-500"
        case .caption2:     "text-xs text-zinc-600"
        }
    }
}

public struct TextMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var styleStr: String?

        for arg in node.arguments {
            if arg.label?.text == "style" || arg.label == nil {
                styleStr = extractEnumCase(from: arg.expression)
            }
        }

        let style = TextStyle(rawValue: styleStr ?? "body") ?? .body

        guard let body = node.trailingClosure else {
            throw MacroError("Text requires a trailing closure")
        }

        return """
        span(.class("\(raw: style.css)")) {
        \(body.statements)
        }
        """
    }
}
