// UI submodules — building blocks for window based terminal interfaces
pub const ZuiBorderedWindow = @import("widgets/zui_window/ZuiBorderedWindow.zig").ZuiBorderedWindow;
pub const ZuiTitleWindow = @import("widgets/zui_window/ZuiTitleWindow.zig").ZuiTitleWindow;
pub const ZuiTextWindow = @import("widgets/zui_window/ZuiTextWindow.zig").ZuiTextWindow;
pub const ZuiWindowBorder = @import("widgets/zui_window/ZuiWindowBorder.zig").ZuiWindowBorder;
pub const ZuiWindow = @import("widgets/zui_window/ZuiWindow.zig").ZuiWindow;
pub const ZuiManager = @import("manager/ZuiManager.zig").ZuiManager;
pub const ZuiStyle = @import("core/ZuiStyle.zig").ZuiStyle;
pub const ZuiStyleClass = @import("core/ZuiStyle.zig").ZuiStyleClass;
pub const ZuiWidget = @import("widgets/core/ZuiWidget.zig").ZuiWidget;
pub const ZuiColorTheme = @import("core/ZuiColorTheme.zig").ZuiColorTheme;
pub const ZuiSize = @import("core/zui_types.zig").ZuiSize;
pub const ZuiPosition2D = @import("core/zui_types.zig").ZuiPosition2D;
pub const ZuiColoredString = @import("core/zui_types.zig").ZuiColoredString;
pub const ZuiWidgetType = @import("core/zui_types.zig").ZuiWidgetType;
pub const ZuiWidgetInfo = @import("core/zui_types.zig").ZuiWidgetInfo;
pub const StyledTextBuffer = @import("core/StyledTextBuffer.zig").StyledTextBuffer;
pub const layout = @import("manager/layout.zig");
