// UI submodules — building blocks for window based terminal interfaces
pub const BorderedWindow = @import("widgets/window/BorderedWindow.zig").BorderedWindow;
pub const TitleWindow = @import("widgets/window/TitleWindow.zig").TitleWindow;
pub const TextWindow = @import("widgets/window/TextWindow.zig").TextWindow;
pub const WindowBorder = @import("widgets/window/WindowBorder.zig").WindowBorder;
pub const Window = @import("widgets/window/Window.zig").Window;
pub const Manager = @import("manager/Manager.zig").Manager;
pub const Style = @import("core/Style.zig").Style;
pub const StyleClass = @import("core/Style.zig").StyleClass;
pub const Widget = @import("widgets/core/Widget.zig").Widget;
pub const ColorTheme = @import("core/ColorTheme.zig").ColorTheme;
pub const Size = @import("core/ui_types.zig").Size;
pub const Position2D = @import("core/ui_types.zig").Position2D;
pub const ColoredString = @import("core/ui_types.zig").ColoredString;
pub const WidgetType = @import("core/ui_types.zig").WidgetType;
pub const WidgetInfo = @import("core/ui_types.zig").WidgetInfo;
pub const StyledTextBuffer = @import("core/StyledTextBuffer.zig").StyledTextBuffer;
pub const layout = @import("manager/layout.zig");
