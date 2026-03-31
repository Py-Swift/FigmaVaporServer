import Elementary

// MARK: - Phantom types

public enum UIBorderColor {
    case gray200, gray300, gray400, gray500, gray600, gray700
    case zinc600, zinc700, zinc800
    case blue300, blue500
    case red300, red500
    case green300, green500
}

public enum UIBorderRadius {
    case none, sm, md, lg, xl, full
}

public enum UIPadding {
    case none, xs, sm, md, lg, xl
}

// MARK: - Macro Declarations

/// Bordered container. Expands to `div(.class("border ...")) { ... }`
@freestanding(expression)
public macro Border<T: HTML>(
    color: UIBorderColor = .zinc700,
    radius: UIBorderRadius = .lg,
    padding: UIPadding = .md,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.div, T> = #externalMacro(module: "PluginUIMacros", type: "BorderMacro")

/// Section wrapper. Expands to `section(.class("flex flex-col ...")) { ... }`
@freestanding(expression)
public macro Section<T: HTML>(
    spacing: LayoutSpacing = .sm,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.section, T> = #externalMacro(module: "PluginUIMacros", type: "SectionMacro")

/// Collapsible disclosure widget. Expands to `_DisclosureGroupContent(...)  { ... }`
@freestanding(expression)
public macro DisclosureGroup<T: HTML>(
    label: String,
    isExpanded: Bool = false,
    @HTMLBuilder _ body: () -> T
) -> _DisclosureGroupContent<T> = #externalMacro(module: "PluginUIMacros", type: "DisclosureGroupMacro")

/// Titled card container. Expands to `_GroupBoxContent(...) { ... }`
@freestanding(expression)
public macro GroupBox<T: HTML>(
    title: String = "",
    @HTMLBuilder _ body: () -> T
) -> _GroupBoxContent<T> = #externalMacro(module: "PluginUIMacros", type: "GroupBoxMacro")
