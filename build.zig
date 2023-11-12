const std = @import("std");

const GraphicsOption = enum {
    None,
    Native,
    Metal,
    OpenGL,
    Vulkan,
    D3D12,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const graphics = b.option(GraphicsOption, "graphics", "graphics framework to use") orelse .None;
    const options = b.addOptions();
    options.addOption(GraphicsOption, "GraphicsBackend", graphics);

    const os_tag = target.os_tag orelse
        b.host.target.os.tag;

    const tests = switch (os_tag) {
        .macos => blk: {
            const zig_objc = b.dependency("zig_objc", .{
                .target = target,
                .optimize = optimize,
            });
            const cocoa = b.dependency("cocoa", .{
                .target = target,
                .optimize = optimize,
            });

            const dependencies: []const std.Build.ModuleDependency = &.{
                .{
                    .name = "zig-objc",
                    .module = zig_objc.module("objc"),
                },
                .{
                    .name = "cocoa",
                    .module = cocoa.module("cocoa"),
                },
                .{
                    .name = "GraphicsBackend",
                    .module = options.createModule(),
                },
            };

            _ = b.addModule("prism", .{
                .source_file = .{
                    .path = "src/main.zig",
                },
                .dependencies = dependencies,
            });
            const tests = b.addTest(.{
                .root_source_file = .{ .path = "src/main.zig" },
                .target = target,
                .optimize = optimize,
            });
            const exe = b.addExecutable(.{
                .name = "metal-test",
                .root_source_file = .{ .path = "src/main.zig" },
                .target = target,
                .optimize = optimize,
            });
            for (dependencies) |dep| {
                tests.addModule(dep.name, dep.module);
                exe.addModule(dep.name, dep.module);
            }
            exe.linkFramework("Cocoa");
            tests.linkFramework("Cocoa");
            if (graphics == .Metal or graphics == .Native) {
                tests.linkFramework("MetalKit");
                tests.linkFramework("Metal");
                exe.linkFramework("MetalKit");
                exe.linkFramework("Metal");
            }
            tests.addOptions("GraphicsBackend", options);
            exe.addOptions("GraphicsBackend", options);
            b.installArtifact(exe);

            break :blk tests;
        },
        else => blk: {
            _ = b.addModule("prism", .{
                .source_file = .{ .path = "src/main.zig" },
            });
            const tests = b.addTest(.{
                .target = target,
                .optimize = optimize,
                .root_source_file = .{
                    .path = "src/main.zig",
                },
            });
            break :blk tests;
        },
    };
    b.installArtifact(tests);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_tests.step);
}
