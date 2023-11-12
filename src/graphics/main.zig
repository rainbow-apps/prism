const std = @import("std");
pub const backend = @import("GraphicsBackend").GraphicsBackend;
const impl = switch (backend) {
    .None => @import("none.zig"),
    .Metal => @import("metal.zig"),
    .Native => blk: {
        switch (@import("builtin").target.os.tag) {
            .macos => break :blk @import("metal.zig"),
            else => break :blk @import("none.zig"),
        }
    },
    else => @compileError("Backend " ++ @tagName(backend) ++ " not yet supported!"),
};

pub const init = impl.init;
pub const deinit = impl.deinit;

pub const Command = union(enum) {
    TriangleMesh: struct {
        color: [][4]f32,
        position: [][2]f32,
        counter: usize = 0,
    },

    pub const body = impl.body;
};

pub const Renderer = struct {
    window_handle: *anyopaque,
    allocator: std.mem.Allocator,
    ready: bool,
    handle: *anyopaque = undefined,
    shaders: std.ArrayList(Shader) = undefined,
    pipelines: std.ArrayList(Pipeline) = undefined,
    commands: std.ArrayList(Command) = undefined,
    drawable_size: extern struct {
        width: f64,
        height: f64,
    } = undefined,

    pub const create = impl.create;
    pub const destroy = impl.destroy;
    pub const addShader = impl.addShader;
    pub const addPipeline = impl.addPipeline;
    pub const Shader = struct {
        kind: Kind,
        handle: *anyopaque,

        pub const Kind = enum { Vertex, Fragment };
    };
    pub const Pipeline = struct {
        handle: *anyopaque,
    };
};
