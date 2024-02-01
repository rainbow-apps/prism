const std = @import("std");

const Backend = enum { cocoa, gtk, win32, none };
const Graphics = enum { metal, openGL, d3d12, vulkan, none };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const t = target.result.os.tag;
    const default_backend: Backend, const native_graphics: Graphics = switch (t) {
        .macos => .{ .cocoa, .metal },
        .windows => .{ .win32, .d3d12 },
        .linux => .{ .gtk, .vulkan },
        else => .{ .none, .none },
    };
    
    const options = b.addOptions();
    const backend = b.option(Backend, "backend", "UI library backend");
    const graphics = b.option(Graphics, "graphics", "graphics library backend");
    options.addOption(Backend, "backend", backend orelse default_backend);
    options.addOption(Graphics, "graphics", graphics orelse native_graphics);

    const zig_objc = b.dependency("zig_objc", .{
        .target = target,
        .optimize = optimize,
    });

    const prism = b.addModule("prism", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/prism.zig" },
        .link_libc = true,
    });
    prism.addOptions("options", options);
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/prism.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    tests.root_module.addImport("zig-objc", zig_objc.module("objc"));
    tests.root_module.addOptions("options", options);
    prism.addImport("zig-objc", zig_objc.module("objc"));
    prism.linkFramework("Cocoa", .{});
    tests.linkFramework("Cocoa");
    prism.linkFramework("Metal", .{});
    prism.linkFramework("MetalKit", .{});
    tests.linkFramework("Metal");
    tests.linkFramework("MetalKit");
    tests.linkFramework("CoreImage");
    b.installArtifact(tests);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_tests.step);
}
