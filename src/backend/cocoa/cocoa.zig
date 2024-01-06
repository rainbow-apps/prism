const objc = @import("zig-objc");
const std = @import("std");

pub const YES = if (objc.c.BOOL == bool) true else @as(i8, 1);
pub const NO = if (objc.c.BOOL == bool) false else @as(i8, 0);

pub const nil = @as(objc.c.id, null);
pub const Nil = @as(objc.c.Class, null);

pub fn NSString(string: [:0]const u8) objc.Object {
    const nsstring = objc.getClass("NSString").?;
    return nsstring.msgSend(objc.Object, "stringWithUTF8String:", .{string.ptr});
}

pub fn alloc(class: anytype) objc.Object {
    switch (@typeInfo(@TypeOf(class))) {
        .Struct => return class.msgSend(objc.Object, "alloc", .{}),
        .Pointer => return objc.getClass(class).?.msgSend(objc.Object, "alloc", .{}),
        else => @compileError("expected class or string, got " ++ @tagName(@typeInfo(@TypeOf(class)))),
    }
}

pub fn NSApp() objc.Object {
    const NSApplication = objc.getClass("NSApplication").?;
    return NSApplication.msgSend(objc.Object, "sharedApplication", .{});
}

pub const NSWindow = struct {
    pub const StyleMask = packed struct {
        titled: bool,
        closable: bool,
        miniaturizable: bool,
        resizable: bool,
        utility_window: bool = false,
        _unused_1: bool = false,
        doc_modal_window: bool = false,
        nonactivating_panel: bool = false,
        _unused_2: u4 = 0,
        unified_title_and_toolbar: bool = false,
        hud_window: bool = false,
        fullscreen: bool = false,
        fullsize_content_view: bool = false,
        _padding: u48 = 0,

        pub const default: StyleMask = .{
            .titled = true,
            .closable = true,
            .miniaturizable = true,
            .fullscreen = false,
            .fullsize_content_view = true,
            .resizable = true,
        };

        comptime {
            std.debug.assert(@sizeOf(@This()) == @sizeOf(u64));
            std.debug.assert(@bitSizeOf(@This()) == @bitSizeOf(u64));
        }
    };
};

pub const NSPoint = extern struct {
    x: f64,
    y: f64,

    pub fn make(x: f64, y: f64) NSPoint {
        return .{
            .x = x,
            .y = y,
        };
    }
};

pub const NSRange = extern struct {
    location: u64,
    length: u64,
};

pub const NSSize = extern struct {
    width: f64,
    height: f64,

    pub fn make(w: f64, h: f64) NSSize {
        return .{
            .width = w,
            .height = h,
        };
    }
};

pub const NSRect = extern struct {
    origin: NSPoint,
    size: NSSize,

    pub fn make(x: f64, y: f64, w: f64, h: f64) NSRect {
        return .{
            .origin = .{ .x = x, .y = y },
            .size = .{ .width = w, .height = h },
        };
    }
};
