import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PluginUIMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        // Layout
        HStackMacro.self,
        VStackMacro.self,
        ZStackMacro.self,
        ScrollViewMacro.self,
        GridMacro.self,
        // Text
        TextMacro.self,
        LinkMacro.self,
        // Control
        ButtonMacro.self,
        TextFieldMacro.self,
        TextEditorMacro.self,
        ToggleMacro.self,
        PickerMacro.self,
        ProgressViewMacro.self,
        // Container
        BorderMacro.self,
        SectionMacro.self,
        DisclosureGroupMacro.self,
        GroupBoxMacro.self,
        // Table
        TableMacro.self,
        TableRowMacro.self,
        TableCellMacro.self,
        // List
        ListViewMacro.self,
        // Media
        ImageMacro.self,
        // Form
        FormMacro.self,
        FormLabelMacro.self,
        SliderMacro.self,
        ColorPickerMacro.self,
        // Feedback
        AlertMacro.self,
    ]
}
