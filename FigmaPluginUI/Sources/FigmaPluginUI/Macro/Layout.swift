import Elementary

// MARK: - Phantom types

public enum HStackAlignment {
    case top, center, bottom, stretch, baseline
}

public enum VStackAlignment {
    case leading, center, trailing, stretch
}

public enum LayoutSpacing {
    case none, xs, sm, md, lg, xl
}

// Alignment types for ZStack
public enum ZStackAlignment {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing
}

/// Scroll axis for ScrollView.
public enum ScrollAxis {
    case vertical, horizontal, both
}

/// Column count for Grid.
public enum GridColumns {
    case one, two, three, four, five, six, twelve
}

// MARK: - Macro Declarations

/// Horizontal flex row. Expands to `div(.class("flex flex-row ...")) { ... }`
@freestanding(expression)
public macro HStack<T: HTML>(
    alignment: HStackAlignment = .center,
    spacing: LayoutSpacing = .md,
    wrap: Bool = false,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.div, T> = #externalMacro(module: "PluginUIMacros", type: "HStackMacro")

/// Vertical flex column. Expands to `div(.class("flex flex-col ...")) { ... }`
@freestanding(expression)
public macro VStack<T: HTML>(
    alignment: VStackAlignment = .stretch,
    spacing: LayoutSpacing = .md,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.div, T> = #externalMacro(module: "PluginUIMacros", type: "VStackMacro")

/// Relative-positioned overlay container. Expands to `div(.class("relative grid ...")) { ... }`
@freestanding(expression)
public macro ZStack<T: HTML>(
    alignment: ZStackAlignment = .center,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.div, T> = #externalMacro(module: "PluginUIMacros", type: "ZStackMacro")

/// Scrollable container. Expands to `div(.class("overflow-y-auto ...")) { ... }`
@freestanding(expression)
public macro ScrollView<T: HTML>(
    _ axes: ScrollAxis = .vertical,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.div, T> = #externalMacro(module: "PluginUIMacros", type: "ScrollViewMacro")

/// CSS grid container. Expands to `div(.class("grid grid-cols-N gap-N ...")) { ... }`
@freestanding(expression)
public macro Grid<T: HTML>(
    columns: GridColumns = .two,
    spacing: LayoutSpacing = .md,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.div, T> = #externalMacro(module: "PluginUIMacros", type: "GridMacro")
