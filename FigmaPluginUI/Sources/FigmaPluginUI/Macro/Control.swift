import Elementary

// MARK: - Phantom types

public enum ButtonVariant {
    case primary, secondary, ghost, danger
}

public enum ButtonSize {
    case xs, sm, md, lg
}

// MARK: - Macro Declaration

/// Styled button. Expands to `button(.class("...")) { ... }`
@freestanding(expression)
public macro Button<T: HTML>(
    variant: ButtonVariant = .secondary,
    size: ButtonSize = .sm,
    onclick: String = "",
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.button, T> = #externalMacro(module: "PluginUIMacros", type: "ButtonMacro")
