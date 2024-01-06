const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zig_objc = b.dependency("zig_objc", .{
        .target = target,
        .optimize = optimize,
    });

    const dependencies: []const std.Build.ModuleDependency = &.{
        .{
            .name = "zig-objc",
            .module = zig_objc.module("objc"),
        },
    };

    _ = b.addModule("prism", .{
        .source_file = .{
            .path = "src/prism.zig",
        },
        .dependencies = dependencies,
    });
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/prism.zig" },
        .target = target,
        .optimize = optimize,
    });
    for (dependencies) |dep| {
        tests.addModule(dep.name, dep.module);
    }
    tests.linkFramework("Cocoa");
    b.installArtifact(tests);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_tests.step);
}
