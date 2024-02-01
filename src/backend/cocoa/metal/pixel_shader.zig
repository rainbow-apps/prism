const prism = @import("../../../prism.zig");
const objc = @import("zig-objc");
const cocoa = @import("../cocoa.zig");
const metal = @import("../metal.zig");
const Layout = @import("../layout.zig");

/// compiles a new pixel shader;
/// for the pixel shader API (uniforms, etc.),
/// see the doc comments in the main file.
/// errorPrinter will be called in the event that an error occurs during compilation.
/// if null, the error will be printed to stderr.
/// ctx is passed to errorPrinter.
pub fn define(
    rendering_context: prism.Graphics.RenderingContext,
    source: [:0]const u8,
    errorPrinter: ?*const fn (ctx: ?*anyopaque, error_str: [*:0]const u8) void,
    ctx: ?*anyopaque,
) prism.Graphics.Err!prism.Graphics.PixelShader {
    const context_id: objc.c.id = @ptrCast(@alignCast(rendering_context.handle));
    const context = objc.Object.fromId(context_id);
    const commandQueue = context.getInstanceVariable("commandQueue");
    const device = commandQueue.getProperty(objc.Object, "device");
    var error_obj: objc.c.id = undefined;
    const library = library: {
        const opts = cocoa.alloc("MTLCompileOptions")
            .msgSend(objc.Object, "init", .{});
        defer opts.msgSend(void, "release", .{});
        const src_str = cocoa.NSString(source);
        defer src_str.msgSend(void, "release", .{});
        break :library device.msgSend(objc.Object, "newLibraryWithSource:options:error:", .{
            src_str,
            opts,
            &error_obj,
        });
    };
    defer library.msgSend(void, "release", .{});

    if (error_obj != cocoa.nil) {
        const error_str = objc.Object.fromId(error_obj);
        defer error_str.msgSend(void, "release", .{});
        const string = error_str.getProperty(objc.Object, "localizedDescription")
            .getProperty([*:0]const u8, "UTF8String");
        if (errorPrinter) |errFn| {
            errFn(ctx, string);
        } else {
            @import("std").debug.print("{s}\n", .{string});
        }
        return error.CompilationFailed;
    }

    const vtxfn = cocoa.NSString("vertexFn");
    defer vtxfn.msgSend(void, "release", .{});
    const frgfn = cocoa.NSString("fragmentFn");
    defer frgfn.msgSend(void, "release", .{});
    const vertex_fn = library.msgSend(objc.Object, "newFunctionWithName:", .{vtxfn});
    defer vertex_fn.msgSend(void, "release", .{});
    const fragment_fn = library.msgSend(objc.Object, "newFunctionWithName:", .{frgfn});
    defer fragment_fn.msgSend(void, "release", .{});

    const descriptor = cocoa.alloc("MTLRenderPipelineDescriptor")
        .msgSend(objc.Object, "init", .{});
    defer descriptor.msgSend(void, "release", .{});
    descriptor.msgSend(void, "reset", .{});
    descriptor.setProperty("vertexFunction", vertex_fn);
    descriptor.setProperty("fragmentFunction", fragment_fn);

    const attachment = cocoa.alloc("MTLRenderPipelineColorAttachmentDescriptor")
        .msgSend(objc.Object, "init", .{});
    defer attachment.msgSend(void, "release", .{});
    attachment.setProperty("pixelFormat", @as(u64, 80));
    attachment.setProperty("blendingEnabled", cocoa.YES);
    attachment.setProperty("destinationAlphaBlendFactor", @as(u64, 1));

    descriptor.getProperty(objc.Object, "colorAttachments")
        .msgSend(void, "setObject:atIndexedSubscript:", .{
        attachment,
        @as(u64, 0),
    });

    var error_obj_2: objc.c.id = undefined;
    const handle = device.msgSend(objc.Object, "newRenderPipelineStateWithDescriptor:error:", .{
        descriptor,
        &error_obj_2,
    });

    if (error_obj_2 != cocoa.nil) {
        const error_str = objc.Object.fromId(error_obj_2);
        defer error_str.msgSend(void, "release", .{});
        const string = error_str.getProperty(objc.Object, "localizedDescription")
            .getProperty([*:0]const u8, "UTF8String");
        if (errorPrinter) |errFn| {
            errFn(ctx, string);
        } else {
            @import("std").debug.print("{s}\n", .{string});
        }
        return error.CompilationFailed;
    }

    return .{
        .handle = handle.value,
    };
}

/// `new_data` must be a One pointer or a Slice and not null.
pub fn updateWidgetUserData(
    self: prism.Graphics.PixelShader,
    widget_to_update: prism.Widget,
    new_data: anytype,
) void {
    _ = self;
    const type_info = @typeInfo(@TypeOf(new_data));
    comptime {
        @import("std").debug.assert(type_info == .Pointer);
        @import("std").debug.assert(type_info.Pointer.size == .One or type_info.Pointer.size == .Slice);
    }
    const T = type_info.Pointer.child;
    const id: objc.c.id = @ptrCast(@alignCast(widget_to_update.handle));
    const prism_view = objc.Object.fromId(id).getInstanceVariable("view");
    const delegate = prism_view.getInstanceVariable("context");
    const userdata = delegate.getInstanceVariable("userData");
    const buffer = userdata.msgSend(*anyopaque, "contents", .{});
    switch (type_info.Pointer.size) {
        .One => {
            const data: *T = @ptrCast(@alignCast(buffer));
            data.* = new_data.*;
            const range: cocoa.NSRange = .{
                .location = 0,
                .length = @sizeOf(T),
            };
            userdata.msgSend(void, "didModifyRange:", .{range});
        },
        .Slice => {
            const data: [*]T = @ptrCast(@alignCast(buffer));
            @memcpy(data[0..new_data.len], new_data);
            const range: cocoa.NSRange = .{
                .location = 0,
                .length = @sizeOf(T) * new_data.len,
            };
            userdata.msgSend(void, "didModifyRange:", .{range});
        },
        else => unreachable,
    }
}

/// disposes the pixel shader's GPU representation.
pub fn dispose(self: prism.Graphics.PixelShader) void {
    const id: objc.c.id = @ptrCast(@alignCast(self.handle));
    const obj = objc.Object.fromId(id);
    obj.msgSend(void, "release", .{});
}

/// creates a widget that uses the pixel shader as its graphics.
/// `userdata_bytes`, if non-null,
/// must be either a single pointer or a slice and will be copied to the GPU;
/// it is up to the user to correctly define and use userdata_bytes in the shader.
pub fn widget(
    self: prism.Graphics.PixelShader,
    context: prism.Graphics.RenderingContext,
    width: prism.Layout.Amount,
    height: prism.Layout.Amount,
    userdata_bytes: anytype,
) prism.AppError!prism.Widget {
    const type_info = @typeInfo(@TypeOf(userdata_bytes));
    comptime {
        const std = @import("std");
        std.debug.assert(type_info == .Pointer or type_info == .Null);
        if (type_info != .Null)
            std.debug.assert(type_info.Pointer.size == .One or type_info.Pointer.size == .Slice);
    }
    const size: u64 = size: {
        if (type_info == .Null) break :size 0;
        break :size if (type_info.Pointer.size == .Slice)
            userdata_bytes.len * @sizeOf(type_info.Pointer.child)
        else
            @sizeOf(type_info.Pointer.child);
    };
    const pipeline_id: objc.c.id = @ptrCast(@alignCast(self.handle));
    const pipeline = objc.Object.fromId(pipeline_id);
    const device = pipeline.getProperty(objc.Object, "device");
    const command_queue_id: objc.c.id = @ptrCast(@alignCast(context.handle));
    const delegate = cocoa.alloc("PrismPixelShaderDelegate")
        .msgSend(objc.Object, "initWithPipeline:context:", .{ pipeline, command_queue_id });

    if (size > 0) {
        const opts: metal.ResourceOptions = .{
            .cache_mode = .Default,
            .storage_mode = .Managed,
            .hazard_mode = .Default,
        };
        const buffer = device.msgSend(objc.Object, "newBufferWithBytes:length:options:", .{
            @as(*const anyopaque, userdata_bytes),
            size,
            @as(u64, @bitCast(opts)),
        });
        delegate.setInstanceVariable("userData", buffer);
    }
    const mouse_data: PixelShaderWidget.MouseData = .{
        .x = 0,
        .y = 0,
        .left = false,
        .right = false,
        .other = false,
        .present = false,
    };
    const opts: metal.ResourceOptions = .{
        .cache_mode = .WriteCombined,
        .storage_mode = .Managed,
        .hazard_mode = .Default,
    };
    const buffer = device.msgSend(objc.Object, "newBufferWithBytes:length:options:", .{
        &mouse_data,
        @as(u64, @sizeOf(PixelShaderWidget.MouseData)),
        @as(u64, @bitCast(opts)),
    });
    delegate.setInstanceVariable("mouseData", buffer);

    const options: prism.Widget.Options = .{
        .width = width,
        .height = height,
        .click = PixelShaderWidget.click,
        .drag = PixelShaderWidget.drag,
        .hover = PixelShaderWidget.hover,
        .context = delegate.value,
        .presence = PixelShaderWidget.presence,
        .other_teardown = PixelShaderWidget.teardown,
        .draw = PixelShaderWidget.draw,
    };
    const block = Layout.Block.init(.{}, PixelShaderWidget.blockFn) catch return error.PlatformCodeFailed;
    const widget_obj = cocoa.alloc("PrismViewController")
        .msgSend(objc.Object, "initWithZigStruct:size:block:", .{ &options, @as(u64, @sizeOf(prism.Widget.Options)), block.context });
    return .{ .handle = widget_obj.value };
}

pub fn setup() prism.AppError!void {
    const PrismPixelShaderDelegate = objc.allocateClassPair(
        objc.getClass("NSObject") orelse return error.PlatformCodeFailed,
        "PrismPixelShaderDelegate",
    ) orelse return error.PlatformCodeFailed;
    defer objc.registerClassPair(PrismPixelShaderDelegate);
    if (!(PrismPixelShaderDelegate.addMethod("drawInMTKView:", drawInMTKView) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismPixelShaderDelegate.addMethod("mtkView:drawableSizeWillChange:", drawableSize) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismPixelShaderDelegate.addMethod("initWithPipeline:context:", initWithPipeline) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!PrismPixelShaderDelegate.addIvar("mouseData")) return error.PlatformCodeFailed;
    if (!PrismPixelShaderDelegate.addIvar("pipeline")) return error.PlatformCodeFailed;
    if (!PrismPixelShaderDelegate.addIvar("context")) return error.PlatformCodeFailed;
    if (!PrismPixelShaderDelegate.addIvar("userData")) return error.PlatformCodeFailed;
    if (!PrismPixelShaderDelegate.addIvar("currentFrameNumber")) return error.PlatformCodeFailed;
    if (!PrismPixelShaderDelegate.addIvar("feedbackTexture")) return error.PlatformCodeFailed;
}

fn initWithPipeline(
    target: objc.c.id,
    sel: objc.c.SEL,
    pipeline: objc.c.id,
    context: objc.c.id,
) callconv(.C) objc.c.id {
    _ = sel;
    const self = objc.Object.fromId(target);
    const pipeline_obj = objc.Object.fromId(pipeline);
    const context_obj = objc.Object.fromId(context);
    self.setInstanceVariable("pipeline", pipeline_obj);
    self.setInstanceVariable("context", context_obj);
    self.setInstanceVariable(
        "currentFrameNumber",
        objc.getClass("NSNumber").?
            .msgSend(objc.Object, "numberWithUnsignedLong:", .{@as(u32, 0)}),
    );
    return self.value;
}

fn drawInMTKView(target: objc.c.id, sel: objc.c.SEL, view_id: objc.c.id) callconv(.C) void {
    _ = sel;
    const self = objc.Object.fromId(target);
    const pipeline = self.getInstanceVariable("pipeline");
    const context = self.getInstanceVariable("context");
    const view = objc.Object.fromId(view_id);
    const ctx = context.getInstanceVariable("commandQueue");
    const buffer = ctx.msgSend(objc.Object, "commandBuffer", .{});
    const descriptor = view.getProperty(objc.Object, "currentRenderPassDescriptor");
    const encoder = buffer.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{descriptor});
    const size = view.getProperty(cocoa.NSSize, "drawableSize");
    encoder.setProperty("viewport", metal.MTLViewport{
        .originX = 0,
        .originY = 0,
        .width = size.width,
        .height = size.height,
        .znear = 0,
        .zfar = 1,
    });

    const frame = self.getInstanceVariable("currentFrameNumber");
    const val = frame.getProperty(u32, "unsignedLongValue");
    const size_and_frame: SizeAndFrame = .{
        .width = @floatCast(size.width),
        .height = @floatCast(size.height),
        .frame = val,
    };

    encoder.setProperty("renderPipelineState", pipeline);
    const full_frame: [6][2]f32 = .{
        .{ -1, -1 }, .{ -1, 1 }, .{ 1, 1 },
        .{ -1, -1 }, .{ 1, -1 }, .{ 1, 1 },
    };
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&full_frame)),
        @as(u64, @sizeOf(@TypeOf(full_frame))),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setFragmentTexture:atIndex:", .{
        self.getInstanceVariable("feedbackTexture"),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setFragmentBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&size_and_frame)),
        @as(u64, @sizeOf(SizeAndFrame)),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setFragmentBuffer:offset:atIndex:", .{
        self.getInstanceVariable("mouseData"),
        @as(u64, 0),
        @as(u64, 1),
    });
    encoder.msgSend(void, "setFragmentBuffer:offset:atIndex:", .{
        self.getInstanceVariable("userData"),
        @as(u64, 0),
        @as(u64, 2),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 3),
        @as(u64, 0),
        @as(u64, 6),
    });

    buffer.msgSend(void, "presentDrawable:", .{
        view.getProperty(objc.Object, "currentDrawable"),
    });
    encoder.msgSend(void, "endEncoding", .{});
    buffer.msgSend(void, "commit", .{});

    frame.msgSend(void, "release", .{});
    self.setInstanceVariable(
        "currentFrameNumber",
        objc.getClass("NSNumber").?
            .msgSend(objc.Object, "numberWithUnsignedLong:", .{val + 1}),
    );
}

fn drawableSize(
    target: objc.c.id,
    sel: objc.c.SEL,
    view_id: objc.c.id,
    size: cocoa.NSSize,
) callconv(.C) void {
    _ = sel;
    const delegate = objc.Object.fromId(target);
    const mtkview = objc.Object.fromId(view_id);
    const device = mtkview.getProperty(objc.Object, "device");
    const buffer = delegate.getInstanceVariable("feedbackTexture");

    const descriptor = cocoa.alloc("MTLTextureDescriptor")
        .msgSend(objc.Object, "init", .{});
    defer descriptor.msgSend(void, "release", .{});
    descriptor.setProperty("width", @as(u64, @intFromFloat(size.width)));
    descriptor.setProperty("height", @as(u64, @intFromFloat(size.height)));
    descriptor.msgSend(void, "setUsage:", .{@as(u64, 3)});
    descriptor.msgSend(void, "setPixelFormat:", .{@as(u64, 80)});
    const new_texture = device.msgSend(objc.Object, "newTextureWithDescriptor:", .{descriptor});

    if (new_texture.value != cocoa.nil) {
        delegate.setInstanceVariable("feedbackTexture", new_texture);
        buffer.msgSend(void, "release", .{});
    }
}

const SizeAndFrame = extern struct {
    width: f32,
    height: f32,
    frame: u32,
};

const PixelShaderWidget = struct {
    const MouseData = extern struct {
        x: f32,
        y: f32,
        left: bool,
        right: bool,
        other: bool,
        present: bool,
    };

    fn click(ctx: ?*anyopaque, x: f64, y: f64, button: prism.MouseButton, is_release: bool) bool {
        const id: objc.c.id = @ptrCast(@alignCast(ctx orelse return true));
        const delegate = objc.Object.fromId(id);
        const data = delegate.getInstanceVariable("mouseData");
        const mouse_data_ptr = data.msgSend(*anyopaque, "contents", .{});
        const mouse_data: *MouseData = @ptrCast(@alignCast(mouse_data_ptr));
        mouse_data.x = @floatCast(x);
        mouse_data.y = @floatCast(y);
        switch (button) {
            .left => mouse_data.left = is_release,
            .right => mouse_data.right = is_release,
            .other => mouse_data.other = is_release,
        }
        const range: cocoa.NSRange = .{
            .location = 0,
            .length = @sizeOf(MouseData),
        };
        data.msgSend(void, "didModifyRange:", .{range});
        return false;
    }

    fn hover(ctx: ?*anyopaque, x: f64, y: f64) bool {
        const id: objc.c.id = @ptrCast(@alignCast(ctx orelse return true));
        const delegate = objc.Object.fromId(id);
        const data = delegate.getInstanceVariable("mouseData");
        const mouse_data_ptr = data.msgSend(*anyopaque, "contents", .{});
        const mouse_data: *MouseData = @ptrCast(@alignCast(mouse_data_ptr));
        mouse_data.x = @floatCast(x);
        mouse_data.y = @floatCast(y);
        const range: cocoa.NSRange = .{
            .location = 0,
            .length = @sizeOf(MouseData),
        };
        data.msgSend(void, "didModifyRange:", .{range});
        return false;
    }

    fn presence(ctx: ?*anyopaque, is_enter: bool) bool {
        const id: objc.c.id = @ptrCast(@alignCast(ctx orelse return true));
        const delegate = objc.Object.fromId(id);
        const data = delegate.getInstanceVariable("mouseData");
        const mouse_data_ptr = data.msgSend(*anyopaque, "contents", .{});
        const mouse_data: *MouseData = @ptrCast(@alignCast(mouse_data_ptr));
        mouse_data.present = is_enter;
        const range: cocoa.NSRange = .{
            .location = 0,
            .length = @sizeOf(MouseData),
        };
        data.msgSend(void, "didModifyRange:", .{range});
        return false;
    }

    fn drag(ctx: ?*anyopaque, x: f64, y: f64, button: prism.MouseButton) bool {
        _ = button;
        return hover(ctx, x, y);
    }

    fn draw(self: *anyopaque) void {
        const id: objc.c.id = @ptrCast(@alignCast(self));
        const prism_view = objc.Object.fromId(id);
        prism_view.getProperty(objc.Object, "subviews")
            .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)})
            .setProperty("needsDisplay", cocoa.YES);
    }

    fn teardown(self: *anyopaque) void {
        const id: objc.c.id = @ptrCast(@alignCast(self));
        const prism_view = objc.Object.fromId(id);
        prism_view.getProperty(objc.Object, "subviews")
            .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)})
            .msgSend(void, "release", .{});
    }

    fn blockFn(
        block_ptr: *const Layout.Block.Context,
        self: objc.c.id,
        new_size: cocoa.NSSize,
        init_view: objc.c.BOOL,
    ) callconv(.C) cocoa.NSSize {
        _ = block_ptr;
        const controller = objc.Object.fromId(self);
        const opts = controller.getInstanceVariable("data")
            .msgSend(*const anyopaque, "bytes", .{});
        const options: *const prism.Widget.Options = @ptrCast(@alignCast(opts));
        const actual_new_size: cocoa.NSSize = .{
            .width = switch (options.width) {
                .fraction => |f| new_size.width * f,
                .pixels => |p| p,
            },
            .height = switch (options.height) {
                .fraction => |f| new_size.height * f,
                .pixels => |p| p,
            },
        };
        const id: objc.c.id = @ptrCast(@alignCast(options.context.?));
        const delegate = objc.Object.fromId(id);
        const device = delegate.getInstanceVariable("pipeline")
            .getProperty(objc.Object, "device");
        if (init_view == cocoa.YES) {
            const view = cocoa.alloc("PrismView")
                .msgSend(objc.Object, "initWithZigStruct:size:frame:", .{
                options, @as(u64, @sizeOf(prism.Widget.Options)),
                cocoa.NSRect{
                    .origin = .{ .x = 0, .y = 0 },
                    .size = actual_new_size,
                },
            });
            controller.setInstanceVariable("view", view);
            const mtkview = cocoa.alloc("MTKView")
                .msgSend(objc.Object, "initWithFrame:device:", .{
                cocoa.NSRect{
                    .origin = .{ .x = 0, .y = 0 },
                    .size = actual_new_size,
                },
                device,
            });
            defer mtkview.msgSend(void, "release", .{});
            view.msgSend(void, "addSubview:", .{mtkview});
            mtkview.setProperty("delegate", delegate);
            mtkview.setProperty("framebufferOnly", cocoa.NO);

            const drawable_size = mtkview.getProperty(cocoa.NSSize, "drawableSize");
            const buffer = delegate.getInstanceVariable("feedbackTexture");

            const descriptor = cocoa.alloc("MTLTextureDescriptor")
                .msgSend(objc.Object, "init", .{});
            defer descriptor.msgSend(void, "release", .{});
            descriptor.setProperty("width", @as(u64, @intFromFloat(drawable_size.width)));
            descriptor.setProperty("height", @as(u64, @intFromFloat(drawable_size.height)));
            descriptor.setProperty("usage", @as(u64, 3));
            descriptor.setProperty("pixelFormat", @as(u64, 80));
            const new_texture = device.msgSend(objc.Object, "newTextureWithDescriptor:", .{descriptor});

            if (new_texture.value != cocoa.nil) {
                delegate.setInstanceVariable("feedbackTexture", new_texture);
                buffer.msgSend(void, "release", .{});
            }
        } else {
            const view = controller.getInstanceVariable("view");
            view.msgSend(void, "setFrameSize:", .{actual_new_size});
            view.getProperty(objc.Object, "subviews")
                .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)})
                .msgSend(void, "setFrameSize:", .{actual_new_size});
        }
        const size = objc.getClass("NSValue").?
            .msgSend(objc.Object, "valueWithSize:", .{actual_new_size});
        controller.setInstanceVariable("layoutSize", size);
        return actual_new_size;
    }
};
