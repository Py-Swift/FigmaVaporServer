import SwiftSyntax
import SwiftSyntaxMacros

public struct ImageMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var src = ""
        var alt = ""
        var width: Int?
        var height: Int?

        for arg in node.arguments {
            switch arg.label?.text {
            case "src":
                src = extractString(from: arg.expression) ?? ""
            case "alt":
                alt = extractString(from: arg.expression) ?? ""
            case "width":
                if let intLit = arg.expression.as(IntegerLiteralExprSyntax.self),
                   let n = Int(intLit.literal.text), n > 0 {
                    width = n
                }
            case "height":
                if let intLit = arg.expression.as(IntegerLiteralExprSyntax.self),
                   let n = Int(intLit.literal.text), n > 0 {
                    height = n
                }
            default: break
            }
        }

        var attrParts = [
            ".src(\"\(src)\")",
            ".alt(\"\(alt)\")",
            ".class(\"max-w-full h-auto object-cover\")",
        ]
        if let w = width  { attrParts.append(".custom(name: \"width\",  value: \"\(w)\")") }
        if let h = height { attrParts.append(".custom(name: \"height\", value: \"\(h)\")") }

        return "img(\(raw: attrParts.joined(separator: ", ")))"
    }
}
