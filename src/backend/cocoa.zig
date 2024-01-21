const prism = @import("../prism.zig");
const cocoa = @import("cocoa/cocoa.zig");
const builtin = @import("builtin");
pub const Window = @import("cocoa/window.zig");
pub const Layout = @import("cocoa/layout.zig");
pub const Widget = @import("cocoa/widget.zig");
const native = @import("cocoa/native.zig");
pub const NativeButton = native.NativeButton;

// graphics implementations
pub const Metal = @import("cocoa/metal.zig");
pub const D3D12 = {
    @compileLog(builtin.os.tag);
    @compileError("D3D12 not supported for this target!");
};
pub const Vulkan = {
    @compileLog(builtin.os.tag);
    @compileError("Vulkan not implemented for this target!");
};
pub const OpenGL = {
    @compileLog(builtin.os.tag);
    @compileError("OpenGL not implemented for this target!");
};

/// creates objective-C classes used by the Cocoa prism backend
/// also calls [NSapplication sharedApplication].
pub fn init() prism.AppError!void {
    try Window.init();
    try Layout.init();
    try Widget.init();
    try native.setup();
    _ = cocoa.NSApp();
}

/// calls [NSApplication stop:nil]
pub fn deinit() void {
    cocoa.NSApp().msgSend(void, "stop:", .{cocoa.nil});
}

pub fn run() void {
    cocoa.NSApp().msgSend(void, "run", .{});
}

pub fn stop() void {
    cocoa.NSApp().msgSend(void, "stop:", .{cocoa.nil});
}
