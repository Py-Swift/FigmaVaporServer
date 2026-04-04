import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Argument Extraction

func extractEnumCase(from expr: ExprSyntax) -> String? {
    if let member = expr.as(MemberAccessExprSyntax.self) {
        return member.declName.baseName.text
    }
    return nil
}

func extractString(from expr: ExprSyntax) -> String? {
    guard let lit = expr.as(StringLiteralExprSyntax.self) else { return nil }
    var result = ""
    for segment in lit.segments {
        if let textSeg = segment.as(StringSegmentSyntax.self) {
            result += textSeg.content.text
        }
    }
    return result.isEmpty ? nil : result
}

func extractBool(from expr: ExprSyntax) -> Bool? {
    guard let b = expr.as(BooleanLiteralExprSyntax.self) else { return nil }
    return b.literal.text == "true"
}

// MARK: - Error

struct MacroError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
