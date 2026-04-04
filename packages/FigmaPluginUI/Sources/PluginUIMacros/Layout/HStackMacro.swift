import SwiftSyntax
import SwiftSyntaxMacros

private enum HStackAlignment: String {
    case top, center, bottom, stretch, baseline

    var css: String {
        switch self {
        case .top:      "items-start"
        case .center:   "items-center"
        case .bottom:   "items-end"
        case .stretch:  "items-stretch"
        case .baseline: "items-baseline"
        }
    }
}

public struct HStackMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var alignmentStr: String?
        var spacingStr: String?
        var wrap = false

        for arg in node.arguments {
            switch arg.label?.text {
            case "alignment": alignmentStr = extractEnumCase(from: arg.expression)
            case "spacing":   spacingStr   = extractEnumCase(from: arg.expression)
            case "wrap":      wrap         = extractBool(from: arg.expression) ?? false
            default: break
            }
        }

        let alignment = HStackAlignment(rawValue: alignmentStr ?? "center") ?? .center
        let spacing   = Spacing(rawValue: spacingStr ?? "md") ?? .md
        var classes   = "flex flex-row w-full \(alignment.css) \(spacing.css)"
        if wrap { classes += " flex-wrap" }

        guard let body = node.trailingClosure else {
            throw MacroError("HStack requires a trailing closure")
        }

        return """
        div(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
