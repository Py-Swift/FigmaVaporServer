import SwiftSyntax
import SwiftSyntaxMacros

private enum ButtonVariant: String {
    case primary, secondary, ghost, danger

    var css: String {
        switch self {
        case .primary:   "bg-blue-600 hover:bg-blue-500 text-white"
        case .secondary: "bg-zinc-700 hover:bg-zinc-600 text-zinc-300 hover:text-white"
        case .ghost:     "bg-transparent hover:bg-zinc-800 text-zinc-400 hover:text-zinc-200"
        case .danger:    "bg-red-700 hover:bg-red-600 text-white"
        }
    }
}

private enum ButtonSize: String {
    case xs, sm, md, lg

    var css: String {
        switch self {
        case .xs: "px-2 py-1 text-xs"
        case .sm: "px-3 py-1.5 text-xs"
        case .md: "px-4 py-2 text-sm"
        case .lg: "px-5 py-2.5 text-base"
        }
    }
}

public struct ButtonMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var variantStr: String?
        var sizeStr: String?
        var onclickStr: String?

        for arg in node.arguments {
            switch arg.label?.text {
            case "variant": variantStr  = extractEnumCase(from: arg.expression)
            case "size":    sizeStr     = extractEnumCase(from: arg.expression)
            case "onclick": onclickStr  = extractString(from: arg.expression)
            default: break
            }
        }

        let variant = ButtonVariant(rawValue: variantStr ?? "secondary") ?? .secondary
        let size    = ButtonSize(rawValue: sizeStr ?? "sm") ?? .sm
        let classes = "\(variant.css) \(size.css) rounded transition-colors cursor-pointer border-0"

        guard let body = node.trailingClosure else {
            throw MacroError("Button requires a trailing closure")
        }

        if let onclick = onclickStr {
            return """
            button(
                .class("\(raw: classes)"),
                .custom(name: "onclick", value: "\(raw: onclick)")
            ) {
            \(body.statements)
            }
            """
        } else {
            return """
            button(.class("\(raw: classes)")) {
            \(body.statements)
            }
            """
        }
    }
}
