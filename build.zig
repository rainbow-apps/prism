const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/prism.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    tests.root_module.addImport("zig-objc", zig_objc.module("objc"));
    prism.addImport("zig-objc", zig_objc.module("objc"));
    prism.linkFramework("Cocoa", .{});
    tests.linkFramework("Cocoa");
    b.installArtifact(tests);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_tests.step);
}
