import SwiftSyntax
import SwiftSyntaxMacros

public struct SliderMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var idStr = ""
        var nameStr = ""
        var minVal = 0
        var maxVal = 100
        var stepVal = 1
        var valueStr: String? = nil

        for arg in node.arguments {
            switch arg.label?.text {
            case "id":   idStr = extractString(from: arg.expression) ?? ""
            case "name": nameStr = extractString(from: arg.expression) ?? ""
            case "min":
                if let lit = arg.expression.as(IntegerLiteralExprSyntax.self),
                   let n = Int(lit.literal.text) { minVal = n }
            case "max":
                if let lit = arg.expression.as(IntegerLiteralExprSyntax.self),
                   let n = Int(lit.literal.text) { maxVal = n }
            case "step":
                if let lit = arg.expression.as(IntegerLiteralExprSyntax.self),
                   let n = Int(lit.literal.text) { stepVal = n }
            case "value":
                if let lit = arg.expression.as(IntegerLiteralExprSyntax.self) {
                    valueStr = lit.literal.text
                } else {
                    valueStr = extractString(from: arg.expression)
                }
            default: break
            }
        }

        let id   = idStr.isEmpty ? nameStr : idStr
        let name = nameStr.isEmpty ? idStr : nameStr

        var attrParts: [String] = [".type(.range)"]
        if !id.isEmpty   { attrParts.append(".id(\"\(id)\")") }
        if !name.isEmpty { attrParts.append(".name(\"\(name)\")") }
        attrParts.append(".class(\"w-full accent-blue-500 cursor-pointer\")")
        attrParts.append(".custom(name: \"min\",  value: \"\(minVal)\")")
        attrParts.append(".custom(name: \"max\",  value: \"\(maxVal)\")")
        attrParts.append(".custom(name: \"step\", value: \"\(stepVal)\")")
        if let v = valueStr { attrParts.append(".value(\"\(v)\")") }

        return "input(\(raw: attrParts.joined(separator: ", ")))"
    }
}
