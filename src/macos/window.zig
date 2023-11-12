const std = @import("std");
const objc = @import("zig-objc");
const cocoa = @import("cocoa");
const prism = @import("prism.zig");
const Window = @import("../window.zig").Window;

pub fn initWithOptions(target: objc.c.id, sel: objc.c.SEL, options: *const anyopaque) callconv(.C) objc.c.id {
    _ = sel;
    const self = objc.Object.fromId(target);
    const window_options: *const Window.Options = @ptrCast(@alignCast(options));
    const mask: cocoa.NSWindow.StyleMask = .{
        .closable = window_options.interaction.closable,
        .fullscreen = false,
        .fullsize_content_view = false,
        .miniaturizable = window_options.interaction.miniaturizable,
        .resizable = window_options.interaction.resizable,
        .titled = window_options.title != null,
    };
    const x = if (window_options.position) |p| p.x else 100;
    const y = if (window_options.position) |p| p.y else 100;
    self.msgSendSuper(objc.getClass("NSWindow").?, void, "initWithContentRect:styleMask:backing:defer:", .{
        cocoa.NSRect.make(x, y, window_options.size.width, window_options.size.height),
        mask,
        @intFromEnum(cocoa.NSWindow.BackingStore.Buffered),
        cocoa.NO,
    });

    self.setProperty("isVisible", .{cocoa.YES});
    if (window_options.title) |t|
        self.setProperty("title", .{cocoa.NSString(t)});
    const exit_on_close = objc.getClass("NSNumber").?
        .msgSend(objc.Object, "numberWithBool:", .{
        if (window_options.interaction.exit_on_close) cocoa.YES else cocoa.NO,
    });
    self.setInstanceVariable("exit_on_close", exit_on_close);
    return self.value;
}

pub fn windowShouldClose(target: objc.c.id, sel: objc.c.SEL, sender: objc.c.id) callconv(.C) objc.c.BOOL {
    _ = sel;
    const self = objc.Object.fromId(target);
    const should_exit = self.getInstanceVariable("exit_on_close")
        .getProperty(objc.c.BOOL, "boolValue");
    if (should_exit == cocoa.YES) {
        cocoa.NSApp().msgSend(void, "terminate:", .{sender});
    }
    return cocoa.YES;
}

pub fn create(options: Window.Options) !Window {
    const PrismWindow = objc.getClass("PrismWindow") orelse return error.ObjcFailed;
    const window = cocoa.alloc(PrismWindow)
        .msgSend(objc.Object, "initWithOptions:", .{&options});

    return .{
        .handle = window.value orelse return error.ObjcFailed,
    };
}

pub fn destroy(self: Window) void {
    const window: objc.c.id = @ptrCast(@alignCast(self.handle));
    const object = objc.Object.fromId(window);
    object.msgSend(void, "performClose:", .{cocoa.nil});
    object.msgSend(void, "release", .{});
}
