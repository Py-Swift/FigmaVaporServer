import Elementary

// MARK: - Phantom types

/// Font styles mirroring SwiftUI's Font.TextStyle.
public enum TextStyle {
    case largeTitle, title, title2, title3
    case headline, subheadline
    case body
    case callout, footnote
    case caption, caption2
}

// MARK: - Macro Declarations

/// Styled inline text span. Expands to `span(.class("...")) { ... }`
///
/// Usage:
/// ```swift
/// #Text(.title) { "Hello, World!" }
/// #Text(.caption) { someVariable }
/// ```
@freestanding(expression)
public macro Text<T: HTML>(
    _ style: TextStyle = .body,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.span, T> = #externalMacro(module: "PluginUIMacros", type: "TextMacro")

/// Anchor link. Expands to `a(.href("..."), .class("...")) { ... }`
///
/// Usage:
/// ```swift
/// #Link(destination: "/lab") { "Go to Lab" }
/// ```
@freestanding(expression)
public macro Link<T: HTML>(
    destination: String,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.a, T> = #externalMacro(module: "PluginUIMacros", type: "LinkMacro")
