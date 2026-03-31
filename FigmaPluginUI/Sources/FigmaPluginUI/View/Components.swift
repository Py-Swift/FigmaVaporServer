import Elementary

// MARK: - _ToggleContent

/// Internal HTML view for the #Toggle macro expansion.
/// Renders a peer-based pill toggle with a label.
public struct _ToggleContent<T: HTML>: HTML {
    private let toggleId: String
    private let toggleName: String
    private let isChecked: Bool
    private let labelView: T

    public init(
        id: String = "",
        name: String = "",
        checked: Bool = false,
        @HTMLBuilder _ label: () -> T
    ) {
        toggleId = id
        toggleName = name
        isChecked = checked
        labelView = label()
    }

    @HTMLBuilder
    public var body: some HTML {
        Elementary.label(.class("inline-flex items-center gap-2 cursor-pointer select-none")) {
            if isChecked {
                input(
                    .type(.checkbox),
                    .id(toggleId),
                    .name(toggleName),
                    .class("sr-only peer"),
                    .custom(name: "checked", value: "")
                )
            } else {
                input(
                    .type(.checkbox),
                    .id(toggleId),
                    .name(toggleName),
                    .class("sr-only peer")
                )
            }
            div(.class("relative w-10 h-6 bg-zinc-600 peer-checked:bg-blue-500 rounded-full transition-colors after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full")) {}
            span(.class("text-sm text-zinc-300")) {
                labelView
            }
        }
    }
}

// MARK: - _DisclosureGroupContent

/// Internal HTML view for the #DisclosureGroup macro expansion.
/// Renders a details/summary disclosure widget with a chevron.
public struct _DisclosureGroupContent<T: HTML>: HTML {
    private let labelStr: String
    private let startExpanded: Bool
    private let groupContent: T

    public init(
        label: String,
        isExpanded: Bool = false,
        @HTMLBuilder _ body: () -> T
    ) {
        labelStr = label
        startExpanded = isExpanded
        groupContent = body()
    }

    @HTMLBuilder
    public var body: some HTML {
        if startExpanded {
            details(
                .class("group border border-zinc-700 rounded-lg overflow-hidden"),
                .custom(name: "open", value: "")
            ) {
                summaryHeader
                contentArea
            }
        } else {
            details(.class("group border border-zinc-700 rounded-lg overflow-hidden")) {
                summaryHeader
                contentArea
            }
        }
    }

    private var summaryHeader: some HTML {
        summary(.class("flex items-center justify-between px-4 py-3 cursor-pointer text-sm font-medium text-zinc-300 hover:text-white hover:bg-zinc-800 list-none select-none")) {
            span { labelStr }
            span(.class("text-zinc-500 transition-transform group-open:rotate-180")) { "▾" }
        }
    }

    private var contentArea: some HTML {
        div(.class("px-4 py-3 flex flex-col gap-3")) {
            groupContent
        }
    }
}

// MARK: - _GroupBoxContent

/// Internal HTML view for the #GroupBox macro expansion.
/// Renders a bordered card with an optional title header.
public struct _GroupBoxContent<T: HTML>: HTML {
    private let titleStr: String?
    private let boxContent: T

    public init(@HTMLBuilder _ body: () -> T) {
        titleStr = nil
        boxContent = body()
    }

    public init(title: String, @HTMLBuilder _ body: () -> T) {
        titleStr = title
        boxContent = body()
    }

    @HTMLBuilder
    public var body: some HTML {
        div(.class("flex flex-col gap-3 border border-zinc-700 rounded-lg p-4")) {
            if let title = titleStr {
                p(.class("text-xs text-zinc-500 uppercase tracking-wider font-medium")) { title }
            }
            boxContent
        }
    }
}

// MARK: - _AlertContent

/// Internal HTML view for the #Alert macro expansion.
public struct _AlertContent<T: HTML>: HTML {
    private let alertStyle: AlertStyle
    private let titleStr: String
    private let alertBody: T

    public init(
        style: AlertStyle = .info,
        title: String = "",
        @HTMLBuilder _ body: () -> T
    ) {
        alertStyle = style
        titleStr = title
        alertBody = body()
    }

    private var containerClass: String {
        switch alertStyle {
        case .info:    return "flex items-start gap-3 rounded-lg px-4 py-3 border bg-blue-950/20 border-blue-800 text-blue-200"
        case .success: return "flex items-start gap-3 rounded-lg px-4 py-3 border bg-green-950/20 border-green-700 text-green-200"
        case .warning: return "flex items-start gap-3 rounded-lg px-4 py-3 border bg-yellow-950/20 border-yellow-700 text-yellow-200"
        case .danger:  return "flex items-start gap-3 rounded-lg px-4 py-3 border bg-red-950/20 border-red-800 text-red-200"
        }
    }

    private var icon: String {
        switch alertStyle {
        case .info:    return "ℹ"
        case .success: return "✓"
        case .warning: return "⚠"
        case .danger:  return "✕"
        }
    }

    @HTMLBuilder
    public var body: some HTML {
        div(.class(containerClass)) {
            span(.class("text-base leading-none mt-0.5 select-none")) { icon }
            div(.class("flex flex-col gap-1 min-w-0")) {
                if !titleStr.isEmpty {
                    p(.class("font-semibold text-sm")) { titleStr }
                }
                div(.class("text-sm opacity-80")) {
                    alertBody
                }
            }
        }
    }
}
