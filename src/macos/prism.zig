const std = @import("std");
const cocoa = @import("cocoa");
const objc = @import("zig-objc");
const window = @import("window.zig");
pub const Window = window.Window;

pub const CocoaError = error{
    ObjcFailed,
};

pub fn init() !void {
    {
        const NSWindow = objc.getClass("NSWindow") orelse return error.ObjcFailed;
        const PrismWindow = objc.allocateClassPair(NSWindow, "PrismWindow") orelse return error.ObjcFailed;
        errdefer deinit();
        defer objc.registerClassPair(PrismWindow);
        if (!(PrismWindow.addMethod("initWithOptions:", window.initWithOptions) catch return error.ObjcFailed))
            return error.ObjcFailed;
        if (!PrismWindow.addIvar("exit_on_close")) return error.ObjcFailed;
        PrismWindow.replaceMethod("windowShouldClose:", window.windowShouldClose);
    }

    _ = cocoa.NSApp();
}

pub fn deinit() void {
    blk: {
        const PrismWindow = objc.getClass("PrismWindow") orelse break :blk;
        _ = PrismWindow;
        // objc.disposeClassPair(PrismWindow);
    }
}

pub fn run() void {
    cocoa.NSApp().msgSend(void, "run", .{});
}

pub fn stop() void {
    cocoa.NSApp().msgSend(void, "stop:", .{cocoa.nil});
}
