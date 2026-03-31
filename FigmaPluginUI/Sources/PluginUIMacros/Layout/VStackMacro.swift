import SwiftSyntax
import SwiftSyntaxMacros

private enum VStackAlignment: String {
    case leading, center, trailing, stretch

    var css: String {
        switch self {
        case .leading:  "items-start"
        case .center:   "items-center"
        case .trailing: "items-end"
        case .stretch:  "items-stretch"
        }
    }
}

public struct VStackMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var alignmentStr: String?
        var spacingStr: String?

        for arg in node.arguments {
            switch arg.label?.text {
            case "alignment": alignmentStr = extractEnumCase(from: arg.expression)
            case "spacing":   spacingStr   = extractEnumCase(from: arg.expression)
            default: break
            }
        }

        let alignment = VStackAlignment(rawValue: alignmentStr ?? "stretch") ?? .stretch
        let spacing   = Spacing(rawValue: spacingStr ?? "md") ?? .md
        let classes   = "flex flex-col w-full \(alignment.css) \(spacing.css)"

        guard let body = node.trailingClosure else {
            throw MacroError("VStack requires a trailing closure")
        }

        return """
        div(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
