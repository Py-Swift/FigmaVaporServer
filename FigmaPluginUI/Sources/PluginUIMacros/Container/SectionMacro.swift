import SwiftSyntax
import SwiftSyntaxMacros

public struct SectionMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        var spacingStr: String?

        for arg in node.arguments {
            if arg.label?.text == "spacing" {
                spacingStr = extractEnumCase(from: arg.expression)
            }
        }

        let spacing = Spacing(rawValue: spacingStr ?? "sm") ?? .sm
        let classes = "flex flex-col w-full \(spacing.css)"

        guard let body = node.trailingClosure else {
            throw MacroError("Section requires a trailing closure")
        }

        return """
        section(.class("\(raw: classes)")) {
        \(body.statements)
        }
        """
    }
}
