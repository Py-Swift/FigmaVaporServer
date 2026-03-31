import SwiftSyntax
import SwiftSyntaxMacros

private enum InputType: String {
    case text, email, password, number, search, url, tel, date

    var htmlType: String { rawValue }
}

public struct TextFieldMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var idStr: String?
        var nameStr: String?
        var placeholder = ""
        var typeStr: String?

        for arg in node.arguments {
            switch arg.label?.text {
            case "id":          idStr       = extractString(from: arg.expression)
            case "name":        nameStr     = extractString(from: arg.expression)
            case "placeholder": placeholder = extractString(from: arg.expression) ?? ""
            case "type":        typeStr     = extractEnumCase(from: arg.expression)
            default: break
            }
        }

        let inputType = InputType(rawValue: typeStr ?? "text") ?? .text
        let id   = idStr   ?? nameStr ?? ""
        let name = nameStr ?? idStr   ?? ""
        let classes = "w-full bg-zinc-800 text-zinc-200 text-sm rounded-md px-3 py-2 border border-zinc-700 focus:outline-none focus:border-zinc-500 placeholder-zinc-600"

        if !id.isEmpty {
            return """
            input(
                .type(.\(raw: inputType.htmlType)),
                .id("\(raw: id)"),
                .name("\(raw: name)"),
                .class("\(raw: classes)"),
                .custom(name: "placeholder", value: "\(raw: placeholder)")
            )
            """
        } else if !placeholder.isEmpty {
            return """
            input(
                .type(.\(raw: inputType.htmlType)),
                .class("\(raw: classes)"),
                .custom(name: "placeholder", value: "\(raw: placeholder)")
            )
            """
        } else {
            return """
            input(.type(.\(raw: inputType.htmlType)), .class("\(raw: classes)"))
            """
        }
    }
}
