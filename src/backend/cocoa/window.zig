const prism = @import("../../prism.zig");
const cocoa = @import("cocoa.zig");
const objc = @import("zig-objc");

/// uses prism.Window.Options to create a window
/// under the hood creates an instance of a subclass of NSWindowController;
/// the returned handle is an objective-C `id` corresponding to this window controller
pub fn create(options: prism.Window.Options) prism.AppError!prism.Window {
    const window = cocoa.alloc("PrismWindowController")
        .msgSend(objc.Object, "initWithZigStruct:", .{&options});
    return .{
        .handle = window.value,
    };
}

/// destroys a window; closing and releasing it.
pub fn destroy(self: prism.Window) void {
    const window_controller_id: objc.c.id = @ptrCast(@alignCast(self.handle));
    const window_controller = objc.Object.fromId(window_controller_id);
    const window = window_controller.getProperty(objc.Object, "window");
    window.msgSend(void, "performClose:", .{cocoa.nil});
    window_controller.msgSend(void, "release", .{});
}

/// replaces the window's content with the given layout
pub fn setContent(self: prism.Window, layout: anytype) void {
    comptime {
        @import("std").debug.assert(@TypeOf(layout) == prism.Layout or @TypeOf(layout) == prism.Widget);
    }
    const window_controller_id: objc.c.id = @ptrCast(@alignCast(self.handle));
    const window_controller = objc.Object.fromId(window_controller_id);
    const window = window_controller.getProperty(objc.Object, "window");
    const frame = window.getProperty(cocoa.NSRect, "frame");
    const controller_id: objc.c.id = @ptrCast(@alignCast(layout.handle));
    const controller = objc.Object.fromId(controller_id);
    const new_size = controller.msgSend(cocoa.NSSize, "attemptResizeWithSize:init:", .{ frame.size, cocoa.YES });
    const view = controller.getInstanceVariable("view");
    window.setProperty("contentView", .{view});
    window_controller.setInstanceVariable("viewController", controller);
    window.msgSend(void, "setContentSize:", .{new_size});
}

pub fn init() prism.AppError!void {
    const PrismWindowController = objc.allocateClassPair(
        objc.getClass("NSWindowController") orelse return error.PlatformCodeFailed,
        "PrismWindowController",
    ) orelse return error.PlatformCodeFailed;
    defer objc.registerClassPair(PrismWindowController);
    if (!(PrismWindowController.addMethod("initWithZigStruct:", initWithZigStruct) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!PrismWindowController.addIvar("options"))
        return error.PlatformCodeFailed;
    if (!PrismWindowController.addIvar("exit_on_close"))
        return error.PlatformCodeFailed;
    if (!PrismWindowController.addIvar("window_title"))
        return error.PlatformCodeFailed;
    if (!PrismWindowController.addIvar("viewController"))
        return error.PlatformCodeFailed;
    PrismWindowController.replaceMethod("loadWindow", loadWindow);
    if (!(PrismWindowController.addMethod("windowShouldClose:", windowShouldClose) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismWindowController.addMethod("windowWillResize:toSize:", windowWillResize) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
}

fn windowShouldClose(target: objc.c.id, sel: objc.c.SEL, sender: objc.c.id) callconv(.C) objc.c.BOOL {
    _ = sender;
    _ = sel;
    const self = objc.Object.fromId(target);
    const exit_on_close = self.getInstanceVariable("exit_on_close")
        .msgSend(objc.c.BOOL, "boolValue", .{});
    if (exit_on_close == cocoa.YES) {
        cocoa.NSApp().msgSend(void, "terminate:", .{self});
    }
    return cocoa.YES;
}

fn windowWillResize(target: objc.c.id, sel: objc.c.SEL, sender: objc.c.id, size: cocoa.NSSize) callconv(.C) cocoa.NSSize {
    _ = sender;
    _ = sel;
    const self = objc.Object.fromId(target);
    const controller = self.getInstanceVariable("viewController");
    const new_size = controller.msgSend(cocoa.NSSize, "attemptResizeWithSize:init:", .{
        size, cocoa.NO,
    });
    return new_size;
}

fn loadWindow(target: objc.c.id, sel: objc.c.SEL) callconv(.C) void {
    _ = sel;
    const self = objc.Object.fromId(target);
    const data = self.getInstanceVariable("options");
    const ptr = data.msgSend(*anyopaque, "bytes", .{});
    const options: *prism.Window.Options = @ptrCast(@alignCast(ptr));
    defer data.msgSend(void, "release", .{});
    const title = self.getInstanceVariable("window_title");
    defer title.msgSend(void, "release", .{});

    const rect = cocoa.NSRect.make(
        options.position.x,
        options.position.y,
        options.size.width,
        options.size.height,
    );
    const stylemask: cocoa.NSWindow.StyleMask = .{
        .closable = options.closable,
        .miniaturizable = options.miniaturizable,
        .resizable = options.resizable,
        .titled = title.value != null,
    };
    const window = cocoa.alloc("NSWindow")
        .msgSend(objc.Object, "initWithContentRect:styleMask:backing:defer:", .{
        rect,
        stylemask,
        @as(u64, 2),
        cocoa.NO,
    });
    defer window.msgSend(void, "release", .{});
    window.setProperty("delegate", .{self});
    self.setProperty("window", .{window});
    window.setProperty("isVisible", .{cocoa.YES});
    if (title.value) |_| window.setProperty("title", .{title});
}

fn initWithZigStruct(
    target: objc.c.id,
    sel: objc.c.SEL,
    zig_struct: *anyopaque,
) callconv(.C) objc.c.id {
    _ = sel;
    const self = objc.Object.fromId(target);
    const options: *prism.Window.Options = @ptrCast(@alignCast(zig_struct));
    if (options.title) |title|
        self.setInstanceVariable("window_title", cocoa.NSString(title));
    const data = objc.getClass("NSData").?
        .msgSend(objc.Object, "dataWithBytes:length:", .{
        zig_struct,
        @as(u64, @sizeOf(prism.Window.Options)),
    });
    const exit_on_close = objc.getClass("NSNumber").?
        .msgSend(objc.Object, "numberWithBool:", .{
        if (options.exit_on_close) cocoa.YES else cocoa.NO,
    });
    self.setInstanceVariable("exit_on_close", exit_on_close);
    self.setInstanceVariable("options", data);
    self.msgSend(void, "loadWindow", .{});
    const window = self.getProperty(objc.Object, "window");
    self.msgSendSuper(
        objc.getClass("NSWindowController").?,
        void,
        "initWithWindow:",
        .{window},
    );

    return self.value;
}

test "create and destroy" {
    const std = @import("std");
    try init();
    _ = cocoa.NSApp();
    const title = try std.testing.allocator.dupeZ(u8, "title");
    const window = try create(.{
        .title = title,
        .size = .{
            .width = 400,
            .height = 200,
        },
        .exit_on_close = true,
    });
    std.testing.allocator.free(title);
    const pid = try std.Thread.spawn(.{}, struct {
        fn runFn(win: prism.Window) void {
            std.time.sleep(std.time.ns_per_s);
            destroy(win);
        }
    }.runFn, .{window});
    cocoa.NSApp().msgSend(void, "run", .{});
    pid.join();
}
