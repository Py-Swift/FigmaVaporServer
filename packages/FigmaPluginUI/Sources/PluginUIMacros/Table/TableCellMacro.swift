import SwiftSyntax
import SwiftSyntaxMacros

private enum CellWidth: String {
    case auto, shrink, w_1_4, w_1_3, w_1_2, w_2_3, w_3_4, w_full

    var css: String {
        switch self {
        case .auto:   ""
        case .shrink: "w-px whitespace-nowrap"
        case .w_1_4:  "w-1/4"
        case .w_1_3:  "w-1/3"
        case .w_1_2:  "w-1/2"
        case .w_2_3:  "w-2/3"
        case .w_3_4:  "w-3/4"
        case .w_full: "w-full"
        }
    }
}

public struct TableCellMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var widthStr: String?

        for arg in node.arguments {
            if arg.label?.text == "width" {
                widthStr = extractEnumCase(from: arg.expression)
            }
        }

        let width = CellWidth(rawValue: widthStr ?? "auto") ?? .auto
        let classes = width.css.isEmpty
            ? "px-3 py-2 text-sm align-middle"
            : "px-3 py-2 text-sm align-middle \(width.css)"

        guard let body = node.trailingClosure else {
            throw MacroError("TableCell requires a trailing closure")
        }

        return """
        td(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
