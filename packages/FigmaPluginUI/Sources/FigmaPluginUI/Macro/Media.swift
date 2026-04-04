import Elementary

// MARK: - Macro Declaration

/// Image element. Expands to `img(.src("..."), .alt("..."), .class("max-w-full h-auto object-cover"))`.
///
/// Usage:
/// ```swift
/// #Image(src: "/public/preview.png", alt: "Figma frame preview")
/// #Image(src: "/public/icon.png", alt: "Icon", width: 48, height: 48)
/// ```
@freestanding(expression)
public macro Image(
    src: String,
    alt: String = "",
    width: Int = 0,
    height: Int = 0
) -> HTMLVoidElement<HTMLTag.img> = #externalMacro(module: "PluginUIMacros", type: "ImageMacro")
