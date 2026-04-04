import SwiftSyntax
import SwiftSyntaxMacros

public struct ColorPickerMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var idStr = ""
        var nameStr = ""
        var valueStr = "#000000"

        for arg in node.arguments {
            switch arg.label?.text {
            case "id":    idStr    = extractString(from: arg.expression) ?? ""
            case "name":  nameStr  = extractString(from: arg.expression) ?? ""
            case "value": valueStr = extractString(from: arg.expression) ?? "#000000"
            default: break
            }
        }

        let id   = idStr.isEmpty ? nameStr : idStr
        let name = nameStr.isEmpty ? idStr : nameStr

        var attrParts: [String] = [".type(.color)"]
        if !id.isEmpty   { attrParts.append(".id(\"\(id)\")") }
        if !name.isEmpty { attrParts.append(".name(\"\(name)\")") }
        attrParts.append(".value(\"\(valueStr)\")")
        attrParts.append(".class(\"w-10 h-10 rounded cursor-pointer bg-transparent p-0.5 border border-zinc-700\")")

        return "input(\(raw: attrParts.joined(separator: ", ")))"
    }
}
