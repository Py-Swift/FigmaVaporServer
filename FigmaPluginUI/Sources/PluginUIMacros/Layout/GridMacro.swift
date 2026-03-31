import SwiftSyntax
import SwiftSyntaxMacros

private enum GridColumns: String {
    case one, two, three, four, five, six, twelve

    var css: String {
        switch self {
        case .one:    "grid-cols-1"
        case .two:    "grid-cols-2"
        case .three:  "grid-cols-3"
        case .four:   "grid-cols-4"
        case .five:   "grid-cols-5"
        case .six:    "grid-cols-6"
        case .twelve: "grid-cols-12"
        }
    }
}

public struct GridMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var columnsStr: String?
        var spacingStr: String?

        for arg in node.arguments {
            switch arg.label?.text {
            case "columns": columnsStr = extractEnumCase(from: arg.expression)
            case "spacing": spacingStr = extractEnumCase(from: arg.expression)
            default: break
            }
        }

        let columns = GridColumns(rawValue: columnsStr ?? "two") ?? .two
        let spacing = Spacing(rawValue: spacingStr ?? "md") ?? .md
        let classes = "grid \(columns.css) \(spacing.css)"

        guard let body = node.trailingClosure else {
            throw MacroError("Grid requires a trailing closure")
        }

        return """
        div(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
