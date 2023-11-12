const std = @import("std");
const builtin = @import("builtin");
const impl = switch (builtin.os.tag) {
    .macos => @import("macos/prism.zig"),
    else => @compileError("target " ++ @tagName(builtin.os.tag) ++ " not yet supported!"),
};
pub const Window = @import("window.zig").Window;

pub const graphics = @import("graphics/main.zig");

pub const init = impl.init;
pub const deinit = impl.deinit;
pub const stop = impl.stop;
pub const run = impl.run;

pub fn main() !void {
    try init();
    defer deinit();

    if (graphics.backend != .None) try graphics.init();
    defer if (graphics.backend != .None) graphics.deinit();
    const window = try Window.create(.{
        .size = .{
            .width = 640,
            .height = 480,
        },
        .interaction = .{
            .exit_on_close = true,
        },
        .title = "metal-test",
    });
    defer window.destroy();
    var render: *graphics.Renderer = undefined;
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const allocator = gpa.allocator();
    if (graphics.backend != .None) {
        render = try graphics.Renderer.create(window, allocator);
        try render.commands.append(.{ .TriangleMesh = .{
            .position = &positions,
            .color = &colors,
        } });

        try render.commands.append(.{ .TriangleMesh = .{
            .position = &positions2,
            .color = &colors2,
        } });
    }
    defer if (graphics.backend != .None) render.destroy();
    run();
}

test "init" {
    try init();
    defer deinit();
    if (graphics.backend != .None) try graphics.init();
    defer if (graphics.backend != .None) graphics.deinit();
    const window = try Window.create(.{
        .size = .{
            .width = 640,
            .height = 480,
        },
        .title = "test window",
    });
    defer window.destroy();

    var render: *graphics.Renderer = undefined;
    if (graphics.backend != .None) render = try graphics.Renderer.create(window, std.testing.allocator);
    defer render.destroy();

    try render.commands.append(.{ .TriangleMesh = .{
        .position = &positions,
        .color = &colors,
    } });
    try render.commands.append(.{ .TriangleMesh = .{
        .position = &positions2,
        .color = &colors2,
    } });

    const pid = try std.Thread.spawn(.{}, waitAndStop, .{});
    run();
    pid.join();
}

fn waitAndStop() void {
    std.time.sleep(5 * std.time.ns_per_s);
    stop();
}

test "refAllDecls" {
    std.testing.refAllDeclsRecursive(@This());
}

var positions: [3][2]f32 = .{ .{ -250.0, 250.0 }, .{ 250.0, 250.0 }, .{ 0.0, -250.0 } };
var colors: [3][4]f32 = .{ .{ 1.0, 0.0, 0.0, 1.0 }, .{ 0.0, 1.0, 0.0, 1.0 }, .{ 0.0, 0.0, 1.0, 1.0 } };

var positions2: [3][2]f32 = .{ .{ -500.0, -125.0 }, .{ -300.0, -125.0 }, .{ -400.0, 125.0 } };
var colors2: [3][4]f32 = .{ .{ 1.0, 0.0, 0.0, 1.0 }, .{ 0.0, 1.0, 0.0, 1.0 }, .{ 0.0, 0.0, 1.0, 1.0 } };
