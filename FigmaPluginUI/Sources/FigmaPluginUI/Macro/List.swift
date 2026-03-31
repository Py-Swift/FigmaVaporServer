import Elementary

/// Unstyled list. Expands to `ul(.class("flex flex-col ...")) { ... }`
@freestanding(expression)
public macro ListView<T: HTML>(
    divided: Bool = false,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.ul, T> = #externalMacro(module: "PluginUIMacros", type: "ListViewMacro")
