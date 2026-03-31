import SwiftSyntax
import SwiftSyntaxMacros

private enum FormMethod: String {
    case get, post
}

public struct FormMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var idStr = ""
        var actionStr = ""
        var methodStr = "post"

        for arg in node.arguments {
            switch arg.label?.text {
            case "id":     idStr     = extractString(from: arg.expression) ?? ""
            case "action": actionStr = extractString(from: arg.expression) ?? ""
            case "method": methodStr = extractEnumCase(from: arg.expression) ?? "post"
            default: break
            }
        }

        let method = FormMethod(rawValue: methodStr) ?? .post

        var attrParts: [String] = []
        if !idStr.isEmpty     { attrParts.append(".id(\"\(idStr)\")") }
        if !actionStr.isEmpty { attrParts.append(".action(\"\(actionStr)\")") }
        attrParts.append(".method(.\(method.rawValue))")
        attrParts.append(".class(\"flex flex-col gap-4\")")

        guard let body = node.trailingClosure else {
            throw MacroError("Form requires a trailing closure")
        }

        return """
        form(\(raw: attrParts.joined(separator: ", "))) {
        \(body.statements)
        }
        """
    }
}
