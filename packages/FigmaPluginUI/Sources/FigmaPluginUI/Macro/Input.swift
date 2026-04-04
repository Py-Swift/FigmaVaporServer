import Elementary

// MARK: - Phantom types

/// Input field types mirroring common HTML input types.
public enum InputType {
    case text, email, password, number, search, url, tel, date
}

// MARK: - Macro Declarations

/// Single-line text input. Expands to `input(.type(...), .class("..."))`.
///
/// Usage:
/// ```swift
/// #TextField(id: "query", placeholder: "Search...", type: .search)
/// ```
@freestanding(expression)
public macro TextField(
    id: String = "",
    name: String = "",
    placeholder: String = "",
    type: InputType = .text
) -> HTMLVoidElement<HTMLTag.input> = #externalMacro(module: "PluginUIMacros", type: "TextFieldMacro")

/// Multi-line textarea. Expands to `textarea(.class("...")) {}`.
///
/// Usage:
/// ```swift
/// #TextEditor(id: "code", placeholder: "Paste code here...", rows: 8)
/// ```
@freestanding(expression)
public macro TextEditor(
    id: String = "",
    name: String = "",
    placeholder: String = "",
    rows: Int = 5
) -> HTMLElement<HTMLTag.textarea, EmptyHTML> = #externalMacro(module: "PluginUIMacros", type: "TextEditorMacro")

/// Pill-style toggle checkbox. Expands to `_ToggleContent { ... }`.
///
/// Usage:
/// ```swift
/// #Toggle(id: "enabled", name: "enabled", checked: true) { "Enable feature" }
/// ```
@freestanding(expression)
public macro Toggle<T: HTML>(
    id: String = "",
    name: String = "",
    checked: Bool = false,
    @HTMLBuilder _ body: () -> T
) -> _ToggleContent<T> = #externalMacro(module: "PluginUIMacros", type: "ToggleMacro")

/// Select dropdown. Expands to `select(.class("...")) { ... }`.
///
/// Usage:
/// ```swift
/// #Picker(id: "mode", name: "mode") {
///     option(.value("kv")) { "KV Mode" }
///     option(.value("canvas")) { "Canvas Mode" }
/// }
/// ```
@freestanding(expression)
public macro Picker<T: HTML>(
    id: String = "",
    name: String = "",
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.select, T> = #externalMacro(module: "PluginUIMacros", type: "PickerMacro")

/// Indeterminate progress bar (animated pulse).
@freestanding(expression)
public macro ProgressView() -> HTMLElement<HTMLTag.div, HTMLElement<HTMLTag.div, EmptyHTML>> = #externalMacro(module: "PluginUIMacros", type: "ProgressViewMacro")

/// Determinate progress bar. `percent` is clamped to 0–100.
@freestanding(expression)
public macro ProgressView(
    percent: Int
) -> HTMLElement<HTMLTag.div, HTMLElement<HTMLTag.div, EmptyHTML>> = #externalMacro(module: "PluginUIMacros", type: "ProgressViewMacro")
