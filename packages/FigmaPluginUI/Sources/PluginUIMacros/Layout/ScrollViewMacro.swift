import SwiftSyntax
import SwiftSyntaxMacros

private enum ScrollAxis: String {
    case vertical, horizontal, both

    var css: String {
        switch self {
        case .vertical:   "overflow-y-auto"
        case .horizontal: "overflow-x-auto"
        case .both:       "overflow-auto"
        }
    }
}

public struct ScrollViewMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var axisStr: String?

        for arg in node.arguments {
            if arg.label == nil || arg.label?.text == "axes" {
                axisStr = extractEnumCase(from: arg.expression)
            }
        }

        let axis = ScrollAxis(rawValue: axisStr ?? "vertical") ?? .vertical
        let classes = "w-full \(axis.css)"

        guard let body = node.trailingClosure else {
            throw MacroError("ScrollView requires a trailing closure")
        }

        return """
        div(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
