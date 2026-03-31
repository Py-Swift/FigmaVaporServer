import SwiftSyntax
import SwiftSyntaxMacros

private enum ZStackAlignment: String {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing

    var css: String {
        switch self {
        case .topLeading:     "items-start justify-start"
        case .top:            "items-start justify-center"
        case .topTrailing:    "items-start justify-end"
        case .leading:        "items-center justify-start"
        case .center:         "items-center justify-center"
        case .trailing:       "items-center justify-end"
        case .bottomLeading:  "items-end justify-start"
        case .bottom:         "items-end justify-center"
        case .bottomTrailing: "items-end justify-end"
        }
    }
}

public struct ZStackMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var alignmentStr: String?

        for arg in node.arguments {
            if arg.label?.text == "alignment" {
                alignmentStr = extractEnumCase(from: arg.expression)
            }
        }

        let alignment = ZStackAlignment(rawValue: alignmentStr ?? "center") ?? .center
        let classes = "relative grid place-items-stretch \(alignment.css)"

        guard let body = node.trailingClosure else {
            throw MacroError("ZStack requires a trailing closure")
        }

        return """
        div(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
