import Elementary

/// A flexible spacer that expands to fill available space in a flex container.
/// Equivalent to SwiftUI's `Spacer`.
///
/// Usage:
/// ```swift
/// #HStack {
///     Text("Left")
///     Spacer()
///     Text("Right")
/// }
/// ```
public struct Spacer: HTML {
    public init() {}

    public var body: some HTML {
        div(.class("flex-1")) {}
    }
}

/// A thin horizontal (or vertical) dividing line.
/// Equivalent to SwiftUI's `Divider`.
///
/// Usage:
/// ```swift
/// #VStack {
///     SomeView()
///     Divider()
///     AnotherView()
/// }
/// ```
public struct Divider: HTML {
    public init() {}

    public var body: some HTML {
        hr(.class("border-zinc-700 my-2"))
    }
}
