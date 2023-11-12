const std = @import("std");
const builtin = @import("builtin");
const impl = switch (builtin.os.tag) {
    .macos => @import("macos/window.zig"),
    else => @compileError("windowing not implemented for " ++ @tagName(builtin.os.tag) ++ " yet!"),
};

pub const Window = struct {
    handle: *anyopaque,

    pub const Options = struct {
        position: ?struct {
            x: f64,
            y: f64,
        } = null,
        size: struct {
            width: f64,
            height: f64,
        },
        title: ?[:0]const u8 = null,
        interaction: struct {
            closable: bool = true,
            resizable: bool = true,
            miniaturizable: bool = true,
            exit_on_close: bool = false,
        } = .{},
    };

    pub const create = impl.create;
    pub const destroy = impl.destroy;
};
