import Elementary

// MARK: - Phantom types

public enum TableLayout {
    case auto, fixed
}

public enum CellWidth {
    case auto, shrink
    case w_1_4, w_1_3, w_1_2, w_2_3, w_3_4, w_full
}

// MARK: - Macro Declarations

/// Responsive table. Expands to `table(.class("w-full ...")) { ... }`
@freestanding(expression)
public macro Table<T: HTML>(
    layout: TableLayout = .auto,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.table, T> = #externalMacro(module: "PluginUIMacros", type: "TableMacro")

/// Table row with bottom border. Expands to `tr(.class("border-b ...")) { ... }`
@freestanding(expression)
public macro TableRow<T: HTML>(
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.tr, T> = #externalMacro(module: "PluginUIMacros", type: "TableRowMacro")

/// Table cell. Expands to `td(.class("px-3 py-2 ...")) { ... }`
@freestanding(expression)
public macro TableCell<T: HTML>(
    width: CellWidth = .auto,
    @HTMLBuilder _ body: () -> T
) -> HTMLElement<HTMLTag.td, T> = #externalMacro(module: "PluginUIMacros", type: "TableCellMacro")
