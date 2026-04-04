import Elementary

// MARK: - Phantom types

/// Visual style for an `Alert` notification box.
public enum AlertStyle {
    case info, success, warning, danger
}

// MARK: - Macro Declaration

/// Styled alert/notification box. Expands to `_AlertContent(style:title:) { ... }`.
///
/// Usage:
/// ```swift
/// #Alert(style: .success, title: "Connected") { "WebSocket is live." }
/// #Alert(style: .danger,  title: "Error")     { "Server returned 500." }
/// ```
@freestanding(expression)
public macro Alert<T: HTML>(
    style: AlertStyle = .info,
    title: String = "",
    @HTMLBuilder _ body: () -> T
) -> _AlertContent<T> = #externalMacro(module: "PluginUIMacros", type: "AlertMacro")
