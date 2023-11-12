const cocoa = @import("cocoa");
const objc = @import("zig-objc");
const std = @import("std");
const graphics = @import("main.zig");
const Renderer = graphics.Renderer;
const Shader = Renderer.Shader;
const Kind = Shader.Kind;
const Pipeline = Renderer.Pipeline;
const Command = graphics.Command;
const Window = @import("../main.zig").Window;

pub fn create(window: Window, allocator: std.mem.Allocator) !*Renderer {
    var self = try allocator.create(Renderer);
    self.* = .{
        .window_handle = window.handle,
        .allocator = allocator,
        .ready = false,
        .shaders = std.ArrayList(Shader).init(allocator),
        .pipelines = std.ArrayList(Pipeline).init(allocator),
        .commands = std.ArrayList(Command).init(allocator),
    };
    self.window_handle = window.handle;

    const controller = cocoa.alloc("PrismGFXController")
        .msgSend(objc.Object, "initWithWindow:context", .{
        @as(objc.c.id, @ptrCast(@alignCast(window.handle))),
        self,
    })
        .msgSend(objc.Object, "autorelease", .{});
    self.handle = controller.value;

    const vtx = try addShader(self, default_vertex_shader, .Vertex, null);
    const frg = try addShader(self, default_fragment_shader, .Fragment, null);
    _ = try addPipeline(self, vtx, frg);
    self.ready = true;
    controller.msgSend(void, "setContext:", .{self});

    return self;
}

pub fn destroy(self: *Renderer) void {
    self.shaders.deinit();
    self.pipelines.deinit();
    self.commands.deinit();
    self.allocator.destroy(self);
}

pub fn addShader(self: *Renderer, source: [:0]const u8, kind: Kind, name: ?[:0]const u8) !Shader {
    var errorObj: objc.c.id = undefined;

    const renderer: objc.c.id = @ptrCast(@alignCast(self.handle));
    const device = objc.Object.fromId(renderer).getProperty(objc.Object, "view")
        .getProperty(objc.Object, "device");
    const library = device.msgSend(objc.Object, "newLibraryWithSource:options:error:", .{
        cocoa.NSString(source),
        cocoa.alloc("MTLCompileOptions")
            .msgSend(objc.Object, "init", .{}),
        &errorObj,
    });

    const string = cocoa.NSString(name orelse blk: {
        break :blk switch (kind) {
            .Fragment => "fragmentFn",
            .Vertex => "vertexFn",
        };
    });

    const handle = library.msgSend(objc.Object, "newFunctionWithName:", .{string});

    if (errorObj != cocoa.nil) {
        cocoa.NSLog(cocoa.NSString("%@").value, errorObj);
    }

    const shader: Shader = .{
        .handle = handle.value,
        .kind = kind,
    };

    try self.shaders.append(shader);
    return shader;
}

pub fn addPipeline(self: *Renderer, vertex_shader: Shader, fragment_shader: Shader) !Pipeline {
    if (vertex_shader.kind != .Vertex or fragment_shader.kind != .Fragment) {
        return error.WrongShaderTypes;
    }

    const renderer = objc.Object.fromId(@as(objc.c.id, @ptrCast(@alignCast(self.handle))));
    const view = renderer.getProperty(objc.Object, "view");
    const device = view.getProperty(objc.Object, "device");

    const vtxfn = objc.Object.fromId(@as(objc.c.id, @ptrCast(@alignCast(vertex_shader.handle))));
    const frgfn = objc.Object.fromId(@as(objc.c.id, @ptrCast(@alignCast(fragment_shader.handle))));

    const descriptor = cocoa.alloc("MTLRenderPipelineDescriptor")
        .msgSend(objc.Object, "init", .{});
    descriptor.setProperty("vertexFunction", .{vtxfn});
    descriptor.setProperty("fragmentFunction", .{frgfn});

    const attachment = descriptor.getProperty(objc.Object, "colorAttachments")
        .msgSend(objc.Object, "objectAtIndexedSubscript:", .{
        @as(u64, 0),
    });
    attachment.setProperty("pixelFormat", .{view.getProperty(u64, "colorPixelFormat")});
    attachment.setProperty("blendingEnabled", .{cocoa.YES});
    attachment.setProperty("destinationAlphaBlendFactor", .{@as(u64, 1)});

    var errorObj: objc.c.id = undefined;
    const handle = device.msgSend(objc.Object, "newRenderPipelineStateWithDescriptor:error:", .{
        descriptor,
        &errorObj,
    });

    if (errorObj != cocoa.nil) {
        cocoa.NSLog(cocoa.NSString("%@").value, errorObj);
    }

    const pipeline: Pipeline = .{
        .handle = handle.value,
    };
    try self.pipelines.append(pipeline);
    return pipeline;
}

pub fn init() !void {
    {
        const NSViewController = objc.getClass("NSViewController") orelse return error.ObjcFailed;
        const PrismGFXController = objc.allocateClassPair(NSViewController, "PrismGFXController") orelse return error.ObjcFailed;
        errdefer deinit();
        defer objc.registerClassPair(PrismGFXController);
        if (!(PrismGFXController.addMethod("initWithWindow:context", initWithWindow) catch return error.ObjcFailed))
            return error.ObjcFailed;
        if (!(PrismGFXController.addMethod("setContext:", setContext) catch return error.ObjcFailed))
            return error.ObjcFailed;
        if (!PrismGFXController.addIvar("ctx")) return error.ObjcFailed;
        PrismGFXController.replaceMethod("viewDidLoad", viewDidLoad);
    }
    errdefer deinit();
    {
        const NSObject = objc.getClass("NSObject") orelse return error.ObjcFailed;
        const PrismGFXRenderer = objc.allocateClassPair(NSObject, "PrismGFXRenderer") orelse return error.ObjcFailed;
        errdefer deinit();
        defer objc.registerClassPair(PrismGFXRenderer);
        if (!PrismGFXRenderer.addIvar("ctx")) return error.ObjcFailed;
        if (!PrismGFXRenderer.addIvar("queue")) return error.ObjcFailed;
        if (!(PrismGFXRenderer.addMethod("initWithMetalKitView:", initWithView) catch return error.ObjcFailed))
            return error.ObjcFailed;
        if (!(PrismGFXRenderer.addMethod("initWithMetalKitView:context:", initWithView) catch return error.ObjcFailed))
            return error.ObjcFailed;
        if (!(PrismGFXRenderer.addMethod("mtkView:drawableSizeWillChange:", drawableSizeWillChange) catch return error.ObjcFailed))
            return error.ObjcFailed;
        if (!(PrismGFXRenderer.addMethod("drawInMTKView:", draw) catch error.ObjcFailed))
            return error.ObjcFailed;
    }
}

pub fn deinit() void {
    blk: {
        const PrismGFXController = objc.getClass("PrismGFXController") orelse break :blk;
        objc.disposeClassPair(PrismGFXController);
    }
    blk: {
        const PrismGFXRenderer = objc.getClass("PrismGFXRenderer") orelse break :blk;
        objc.disposeClassPair(PrismGFXRenderer);
    }
}

pub fn body(self: *Command, renderer: *const Renderer, encoder: *anyopaque) void {
    const encoder_id: objc.c.id = @ptrCast(@alignCast(encoder));
    const command_encoder = objc.Object.fromId(encoder_id);
    switch (self.*) {
        .TriangleMesh => |c| {
            const pipeline: objc.c.id = @ptrCast(@alignCast(renderer.pipelines.items[0].handle));
            command_encoder.setProperty("renderPipelineState", .{pipeline});
            command_encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
                @as([*]const u8, @ptrCast(c.position.ptr)),
                @as(u64, @sizeOf([2]f32) * c.position.len),
                @as(u64, 0),
            });
            command_encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
                @as([*]const u8, @ptrCast(c.color.ptr)),
                @as(u64, @sizeOf([4]f32) * c.color.len),
                @as(u64, 1),
            });
            const size: [2]f32 = .{ @floatCast(renderer.drawable_size.width), @floatCast(renderer.drawable_size.height) };
            command_encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
                @as([*]const u8, @ptrCast(&size)),
                @as(u64, @sizeOf([2]f32)),
                @as(u64, 2),
            });
            command_encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
                @as(u64, 3),
                @as(u64, 0),
                @as(u64, c.color.len),
            });

            const delta: f32 = if (c.counter < 60) 5 else -5;
            for (c.position) |*v| {
                v[0] += delta;
                v[1] += delta;
            }
            self.TriangleMesh.counter += 1;
            if (c.counter >= 120) self.TriangleMesh.counter = 0;
        },
    }
}

// -- objc functions -- //

fn initWithWindow(target: objc.c.id, sel: objc.c.SEL, window: objc.c.id, context: *anyopaque) callconv(.C) objc.c.id {
    _ = sel;
    const self = objc.Object.fromId(target);
    const object = objc.Object.fromId(window);
    const frame = object.getProperty(cocoa.NSRect, "frame");

    const ctx = objc.getClass("NSValue").?
        .msgSend(objc.Object, "valueWithPointer:", .{context});

    const view = cocoa.alloc("MTKView")
        .msgSend(objc.Object, "initWithFrame:device:", .{
        cocoa.NSRect.make(0, 0, frame.size.width, frame.size.height),
        MTLCreateSystemDefaultDevice(),
    })
        .msgSend(objc.Object, "autorelease", .{});
    view.setProperty("wantsLayer", .{cocoa.YES});

    self.msgSendSuper(objc.getClass("NSViewController").?, void, "init", .{});
    self.setProperty("view", .{view});
    self.setInstanceVariable("ctx", ctx);
    self.msgSend(void, "viewDidLoad", .{});

    object.setProperty("contentViewController", .{self});
    return self.value;
}

fn setContext(target: objc.c.id, sel: objc.c.SEL, context: *anyopaque) callconv(.C) void {
    _ = sel;
    const self = objc.Object.fromId(target);
    const ctx = objc.getClass("NSValue").?
        .msgSend(objc.Object, "valueWithPointer:", .{context});
    self.setInstanceVariable("ctx", ctx);
    const view = self.getProperty(objc.Object, "view");
    const renderer = view.getProperty(objc.Object, "delegate");
    const ctx2 = objc.getClass("NSValue").?
        .msgSend(objc.Object, "valueWithPointer:", .{context});
    renderer.setInstanceVariable("ctx", ctx2);
}

fn viewDidLoad(target: objc.c.id, sel: objc.c.SEL) callconv(.C) void {
    _ = sel;
    const self = objc.Object.fromId(target);
    self.msgSendSuper(objc.getClass("NSViewController").?, void, "viewDidLoad", .{});
    const view = self.getProperty(objc.Object, "view");

    const ctx = self.getInstanceVariable("ctx");

    const renderer = cocoa.alloc("PrismGFXRenderer")
        .msgSend(objc.Object, "initWithMetalKitView:context:", .{ view, ctx })
        .msgSend(objc.Object, "autorelease", .{});

    const device = view.getProperty(objc.Object, "device");
    const queue = device.msgSend(objc.Object, "newCommandQueue", .{})
        .msgSend(objc.Object, "autorelease", .{});
    renderer.setInstanceVariable("ctx", ctx);
    renderer.setInstanceVariable("queue", queue);

    renderer.msgSend(void, "mtkView:drawableSizeWillChange:", .{
        view,
        view.getProperty(cocoa.NSSize, "drawableSize"),
    });
    view.setProperty("delegate", .{renderer});
}

fn initWithView(target: objc.c.id, sel: objc.c.SEL, view: objc.c.id) callconv(.C) objc.c.id {
    _ = view;
    _ = sel;
    return target;
}

fn initWithViewContext(target: objc.c.id, sel: objc.c.SEL, view: objc.c.id, context: objc.c.id) callconv(.C) objc.c.id {
    _ = view;
    _ = sel;
    const self = objc.Object.fromId(target)
        .msgSendSuper(objc.getClass("NSObject").?, objc.Object, "init", .{});
    std.debug.assert(context != cocoa.nil);
    self.setInstanceVariable("ctx", objc.Object.fromId(context));
}

fn drawableSizeWillChange(target: objc.c.id, sel: objc.c.SEL, view: objc.c.id, size: cocoa.NSSize) callconv(.C) void {
    _ = view;
    _ = sel;
    const self = objc.Object.fromId(target);
    const ptr = self.getInstanceVariable("ctx");

    const ctx = ptr.getProperty(*anyopaque, "pointerValue");
    const renderer: *Renderer = @ptrCast(@alignCast(ctx));
    renderer.drawable_size.width = size.width;
    renderer.drawable_size.height = size.height;
}

fn draw(target: objc.c.id, sel: objc.c.SEL, view: objc.c.id) callconv(.C) void {
    _ = sel;
    const self = objc.Object.fromId(target);
    const mtkview = objc.Object.fromId(view);
    const ctx = self.getInstanceVariable("ctx")
        .getProperty(*anyopaque, "pointerValue");
    const renderer: *Renderer = @ptrCast(@alignCast(ctx));
    const command_queue = self.getInstanceVariable("queue");
    const command_buffer = command_queue.msgSend(objc.Object, "commandBuffer", .{});
    const descriptor = mtkview.getProperty(objc.Object, "currentRenderPassDescriptor");
    const encoder = command_buffer.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{descriptor});
    for (renderer.commands.items) |*cmd| {
        encoder.setProperty("viewport", .{
            MTLViewport.make(0, 0, renderer.drawable_size.width, renderer.drawable_size.height, 0, 1),
        });
        cmd.body(renderer, encoder.value);
    }
    encoder.msgSend(void, "endEncoding", .{});
    command_buffer.msgSend(void, "presentDrawable:", .{
        mtkview.getProperty(objc.Object, "currentDrawable"),
    });
    command_buffer.msgSend(void, "commit", .{});
}

extern "C" fn MTLCreateSystemDefaultDevice() objc.c.id;

const default_vertex_shader =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\
    \\struct RasterizeData
    \\{
    \\ float4 position [[position]];
    \\ float4 color;
    \\};
    \\
    \\vertex RasterizeData vertexFn(uint vertexID [[vertex_id]],
    \\    constant float2 *positions [[buffer(0)]],
    \\    constant float4 *colors [[buffer (1)]],
    \\    constant float2 *size [[buffer(2)]])
    \\{
    \\  RasterizeData out;
    \\
    \\  out.position = float4(0.0, 0.0, 0.0, 1.0);
    \\  out.position.xy = positions[vertexID].xy / (size[0].xy / 2.0);
    \\  out.color = colors[vertexID].xyzw;
    \\
    \\  return out;
    \\}
    \\
;
const default_fragment_shader =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\
    \\struct RasterizeData
    \\{
    \\ float4 position [[position]];
    \\ float4 color;
    \\};
    \\
    \\fragment float4 fragmentFn(RasterizeData in [[stage_in]])
    \\{
    \\  return in.color;
    \\}
    \\
;

const MTLViewport = extern struct {
    originX: f64,
    originY: f64,
    width: f64,
    height: f64,
    znear: f64,
    zfar: f64,

    fn make(originX: f64, originY: f64, width: f64, height: f64, znear: f64, zfar: f64) MTLViewport {
        return .{
            .originX = originX,
            .originY = originY,
            .width = width,
            .height = height,
            .znear = znear,
            .zfar = zfar,
        };
    }
};
