import Elementary

// MARK: - Badge

/// Visual style variants for a `Badge`.
public enum BadgeStyle {
    case gray, blue, green, yellow, red
}

private extension BadgeStyle {
    var css: String {
        switch self {
        case .gray:   return "bg-zinc-700 text-zinc-300"
        case .blue:   return "bg-blue-900/60 text-blue-300"
        case .green:  return "bg-green-900/60 text-green-300"
        case .yellow: return "bg-yellow-900/60 text-yellow-300"
        case .red:    return "bg-red-900/60 text-red-300"
        }
    }
}

/// A compact pill label for status indicators or category tags.
///
/// Usage:
/// ```swift
/// Badge("Running", style: .green)
/// Badge("Error",   style: .red)
/// ```
public struct Badge: HTML {
    private let text: String
    private let badgeStyle: BadgeStyle

    public init(_ text: String, style: BadgeStyle = .gray) {
        self.text = text
        self.badgeStyle = style
    }

    public var body: some HTML {
        span(.class("inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium \(badgeStyle.css)")) {
            text
        }
    }
}

// MARK: - LabeledContent

/// A horizontal key–value row for displaying metadata or properties.
///
/// Usage:
/// ```swift
/// LabeledContent("File ID",     value: "fig:abc123")
/// LabeledContent("Frame count", value: "12")
/// ```
public struct LabeledContent: HTML {
    private let labelText: String
    private let valueText: String

    public init(_ label: String, value: String) {
        self.labelText = label
        self.valueText = value
    }

    public var body: some HTML {
        div(.class("flex items-center justify-between py-1.5 border-b border-zinc-800 last:border-0")) {
            span(.class("text-xs text-zinc-500")) { labelText }
            span(.class("text-xs text-zinc-200 font-mono")) { valueText }
        }
    }
}

// MARK: - CodeBlock

/// A styled monospace code block with optional language label header.
///
/// Usage:
/// ```swift
/// CodeBlock(rawCode, language: "python")
/// CodeBlock(generatedSwift)
/// ```
public struct CodeBlock: HTML {
    private let codeText: String
    private let language: String

    public init(_ code: String, language: String = "") {
        self.codeText = code
        self.language = language
    }

    @HTMLBuilder
    public var body: some HTML {
        div(.class("rounded-lg border border-zinc-700 overflow-hidden bg-zinc-900")) {
            if !language.isEmpty {
                div(.class("flex items-center px-3 py-1.5 bg-zinc-800 border-b border-zinc-700")) {
                    span(.class("text-xs text-zinc-500 font-mono")) { language }
                }
            }
            pre(.class("m-0 overflow-x-auto")) {
                code(.class("block p-4 text-sm text-green-400 font-mono whitespace-pre")) {
                    codeText
                }
            }
        }
    }
}
