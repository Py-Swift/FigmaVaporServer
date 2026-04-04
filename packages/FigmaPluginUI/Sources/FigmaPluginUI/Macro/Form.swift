import Elementary

// MARK: - Phantom types

/// HTTP method for a form submission.
public enum FormMethod {
    case get, post
}

// MARK: - Macro Declarations

/// HTML form container. Expands to `form(.action("..."), .method(.post), .class("flex flex-col gap-4")) { ... }`
///
/// Usage:
/// ```swift
/// #Form(id: "search", action: "/search", method: .get) {
///     #TextField(id: "q", placeholder: "Search...")
///     #Button(variant: .primary) { "Search" }
/// }
/// ```
@freestanding(expression)
public macro Form<T: HTML>(
    id: String = "",
    action: String = "",
    method: FormMethod = .post,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.form, T> = #externalMacro(module: "PluginUIMacros", type: "FormMacro")

/// Form field label. Expands to `label(.for("..."), .class("text-xs font-medium text-zinc-400 block")) { ... }`
///
/// Usage:
/// ```swift
/// #FormLabel(for: "username") { "Username" }
/// #TextField(id: "username", placeholder: "Enter username")
/// ```
@freestanding(expression)
public macro FormLabel<T: HTML>(
    for fieldID: String = "",
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.label, T> = #externalMacro(module: "PluginUIMacros", type: "FormLabelMacro")

/// Range slider. Expands to `input(.type(.range), .class("w-full accent-blue-500"), ...)`.
///
/// Usage:
/// ```swift
/// #Slider(id: "opacity", name: "opacity", min: 0, max: 100, value: 80)
/// ```
@freestanding(expression)
public macro Slider(
    id: String = "",
    name: String = "",
    min: Int = 0,
    max: Int = 100,
    step: Int = 1,
    value: Int = 0
) -> HTMLVoidElement<HTMLTag.input> = #externalMacro(module: "PluginUIMacros", type: "SliderMacro")

/// Color input picker. Expands to `input(.type(.color), .value("..."), .class("..."))`.
///
/// Usage:
/// ```swift
/// #ColorPicker(id: "bg", name: "bg", value: "#1e1e2e")
/// ```
@freestanding(expression)
public macro ColorPicker(
    id: String = "",
    name: String = "",
    value: String = "#000000"
) -> HTMLVoidElement<HTMLTag.input> = #externalMacro(module: "PluginUIMacros", type: "ColorPickerMacro")
