import SwiftSyntax
import SwiftSyntaxMacros

private enum BorderColor: String {
    case gray200, gray300, gray400, gray500, gray600, gray700
    case zinc600, zinc700, zinc800
    case blue300, blue500
    case red300, red500
    case green300, green500

    var css: String {
        switch self {
        case .gray200:  "border-gray-200"
        case .gray300:  "border-gray-300"
        case .gray400:  "border-gray-400"
        case .gray500:  "border-gray-500"
        case .gray600:  "border-gray-600"
        case .gray700:  "border-gray-700"
        case .zinc600:  "border-zinc-600"
        case .zinc700:  "border-zinc-700"
        case .zinc800:  "border-zinc-800"
        case .blue300:  "border-blue-300"
        case .blue500:  "border-blue-500"
        case .red300:   "border-red-300"
        case .red500:   "border-red-500"
        case .green300: "border-green-300"
        case .green500: "border-green-500"
        }
    }
}

public struct BorderMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var colorStr: String?
        var radiusStr: String?
        var paddingStr: String?

        for arg in node.arguments {
            switch arg.label?.text {
            case "color":   colorStr   = extractEnumCase(from: arg.expression)
            case "radius":  radiusStr  = extractEnumCase(from: arg.expression)
            case "padding": paddingStr = extractEnumCase(from: arg.expression)
            default: break
            }
        }

        let color   = BorderColor(rawValue: colorStr ?? "zinc700") ?? .zinc700
        let radius  = BorderRadius(rawValue: radiusStr ?? "lg") ?? .lg
        let padding = UIPadding(rawValue: paddingStr ?? "md") ?? .md
        let classes = "border \(color.css) \(radius.css) \(padding.css)"

        guard let body = node.trailingClosure else {
            throw MacroError("Border requires a trailing closure")
        }

        return """
        div(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
