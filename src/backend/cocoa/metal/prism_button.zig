const prism = @import("../../../prism.zig");
const metal = @import("../metal.zig");
const cocoa = @import("../cocoa.zig");
const Layout = @import("../layout.zig");
const objc = @import("zig-objc");
const src = @embedFile("prism_button.metal");

pub fn compile(rendering_context: objc.Object) prism.Graphics.Err!void {
    const commandQueue = rendering_context.getInstanceVariable("commandQueue");
    const device = commandQueue.getProperty(objc.Object, "device");
    var err_obj: objc.c.id = undefined;
    const library = library: {
        const opts = cocoa.alloc("MTLCompileOptions")
            .msgSend(objc.Object, "init", .{});
        defer opts.msgSend(void, "release", .{});
        const src_str = cocoa.NSString(src);
        defer src_str.msgSend(void, "release", .{});
        break :library device.msgSend(objc.Object, "newLibraryWithSource:options:error:", .{
            src_str,
            opts,
            &err_obj,
        });
    };
    defer library.msgSend(void, "release", .{});
    if (err_obj != cocoa.nil) {
        const error_str = objc.Object.fromId(err_obj);
        defer error_str.msgSend(void, "release", .{});
        const string = error_str.getProperty(objc.Object, "localizedDescription")
            .getProperty([*:0]const u8, "UTF8String");
        @import("std").debug.print("{s}\n", .{string});
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
        @import("std").debug.print("{s}\n", .{string});
        return error.CompilationFailed;
    }
    rendering_context.setInstanceVariable("prismButtonPipeline", handle);
}

pub fn widget(
    context: prism.Graphics.RenderingContext,
    options: prism.Graphics.PrismButton.Options,
) prism.AppError!prism.Widget {
    const context_id: objc.c.id = @ptrCast(@alignCast(context.handle));
    const graphicsContext = objc.Object.fromId(context_id);
    const device = graphicsContext.getInstanceVariable("commandQueue")
        .getProperty(objc.Object, "device");
    const pipeline = graphicsContext.getInstanceVariable("prismButtonPipeline");
    const delegate = cocoa.alloc("PrismButtonDelegate")
        .msgSend(objc.Object, "initWithPipeline:context:", .{ pipeline, context_id });

    const data = objc.getClass("NSData").?
        .msgSend(objc.Object, "dataWithBytes:length:", .{ &options, @as(u64, @sizeOf(prism.Graphics.PrismButton.Options)) });
    delegate.setInstanceVariable("data", data);
    const text = cocoa.NSString(options.text.string);
    defer text.msgSend(void, "release", .{});
    const font = cocoa.NSString(options.text.font_name);
    defer font.msgSend(void, "release", .{});
    const font_size = objc.getClass("NSNumber").?
        .msgSend(objc.Object, "numberWithInt:", .{@as(c_int, options.text.font_size)});
    defer font_size.msgSend(void, "release", .{});
    const scale_factor = objc.getClass("NSNumber").?
        .msgSend(objc.Object, "numberWithDouble:", .{@as(f64, 2.0)});
    defer scale_factor.msgSend(void, "release", .{});
    const padding = objc.getClass("NSNumber").?
        .msgSend(objc.Object, "numberWithInt:", .{@as(c_int, 0)});
    defer padding.msgSend(void, "release", .{});

    const text_image_generator = cocoa.NSString("CIAttributedTextImageGenerator");
    defer text_image_generator.msgSend(void, "release", .{});
    const input_text = cocoa.NSString("inputText");
    defer input_text.msgSend(void, "release", .{});
    const input_font_name = cocoa.NSString("inputFontName");
    defer input_font_name.msgSend(void, "release", .{});
    const input_font_size = cocoa.NSString("inputFontSize");
    defer input_font_size.msgSend(void, "release", .{});
    const input_padding = cocoa.NSString("inputPadding");
    defer input_padding.msgSend(void, "release", .{});
    const input_scale_factor = cocoa.NSString("inputScaleFactor");
    defer input_scale_factor.msgSend(void, "release", .{});

    const text_attrs = cocoa.alloc("NSMutableDictionary")
        .msgSend(objc.Object, "init", .{});
    defer text_attrs.msgSend(void, "release", .{});

    text_attrs.msgSend(void, "setValue:forKey:", .{
        objc.getClass("NSColor").?
            .msgSend(objc.Object, "colorWithCalibratedRed:green:blue:alpha:", .{
            @as(f64, 1),
            @as(f64, 1),
            @as(f64, 1),
            @as(f64, 1),
        }),
        @extern(objc.c.id, .{
            .name = "NSStrokeColorAttributeName",
        }).*,
    });
    text_attrs.msgSend(void, "setValue:forKey:", .{
        objc.getClass("NSColor").?
            .msgSend(objc.Object, "colorWithCalibratedRed:green:blue:alpha:", .{
            @as(f64, 1),
            @as(f64, 1),
            @as(f64, 1),
            @as(f64, 1),
        }),
        @extern(objc.c.id, .{
            .name = "NSForegroundColorAttributeName",
        }).*,
    });
    text_attrs.msgSend(void, "setValue:forKey:", .{
        objc.getClass("NSFont").?
            .msgSend(objc.Object, "fontWithName:size:", .{
            font,
            @as(f64, @floatFromInt(options.text.font_size)),
        }),
        @extern(objc.c.id, .{
            .name = "NSFontAttributeName",
        }).*,
    });

    const attr_str = cocoa.alloc("NSAttributedString")
        .msgSend(objc.Object, "initWithString:attributes:", .{
        text,
        text_attrs,
    });

    const dict = cocoa.alloc("NSMutableDictionary")
        .msgSend(objc.Object, "init", .{});
    defer dict.msgSend(void, "release", .{});
    dict.msgSend(void, "setValue:forKey:", .{
        attr_str,
        input_text,
    });
    dict.msgSend(void, "setValue:forKey:", .{
        padding,
        input_padding,
    });
    dict.msgSend(void, "setValue:forKey:", .{
        scale_factor,
        input_scale_factor,
    });

    const text_filter = objc.getClass("CIFilter").?
        .msgSend(objc.Object, "filterWithName:withInputParameters:", .{
        text_image_generator,
        dict,
    });

    const img = text_filter.getProperty(objc.Object, "outputImage")
        .msgSend(objc.Object, "imageByApplyingOrientation:", .{@as(c_int, 4)});

    delegate.setInstanceVariable("text", img);

    const size = if (img.value != cocoa.nil)
        img.getProperty(cocoa.NSRect, "extent").size
    else
        cocoa.NSSize{
            .height = 1,
            .width = 1,
        };

    const desc = objc.getClass("MTLTextureDescriptor").?
        .msgSend(objc.Object, "texture2DDescriptorWithPixelFormat:width:height:mipmapped:", .{
        @as(u64, 80),
        @as(u64, @intFromFloat(@ceil(size.width))),
        @as(u64, @intFromFloat(@ceil(size.height))),
        cocoa.NO,
    });
    defer desc.msgSend(void, "release", .{});
    desc.setProperty("usage", @as(u64, 0x17));

    const new_texture = device.msgSend(objc.Object, "newTextureWithDescriptor:", .{desc});

    const image_context = delegate.getInstanceVariable("context")
        .getInstanceVariable("imageContext");
    const cs = metal.CGColorSpaceCreateDeviceRGB();
    defer objc.Object.fromId(cs).msgSend(void, "release", .{});
    image_context.msgSend(void, "render:toMTLTexture:commandBuffer:bounds:colorSpace:", .{
        img,
        new_texture,
        cocoa.nil,
        cocoa.NSRect{
            .origin = .{ .x = 0, .y = 0 },
            .size = size,
        },
        cs,
    });
    delegate.setInstanceVariable("textTexture", new_texture);

    const shader_data: ShaderData = .{
        .frame_nr = 0,
        .text_width = @floatCast(size.width),
        .text_height = @floatCast(size.height),
        .horizontal_pad = switch (options.horizontal_pad) {
            .pixels => |p| @floatCast(p),
            .fraction => |f| @floatCast(size.width * f),
        },
        .vertical_pad = switch (options.vertical_pad) {
            .pixels => |p| @floatCast(p),
            .fraction => |f| @floatCast(size.height * f),
        },
        .border_thickness = options.border_thickness,
        .bg = .{ options.bg.r, options.bg.g, options.bg.b, options.bg.a },
        .fg = .{ options.fg.r, options.fg.g, options.fg.b, options.fg.a },
        .hl_bg = .{ options.hl_bg.r, options.hl_bg.g, options.hl_bg.b, options.hl_bg.a },
        .hl_fg = .{ options.hl_fg.r, options.hl_fg.g, options.hl_fg.b, options.hl_fg.a },
        .present = false,
        .clicked = false,
    };
    const opts: metal.ResourceOptions = .{
        .cache_mode = .WriteCombined,
        .storage_mode = .Managed,
        .hazard_mode = .Default,
    };
    const buffer = device.msgSend(objc.Object, "newBufferWithBytes:length:options:", .{
        &shader_data,
        @as(u64, @sizeOf(ShaderData)),
        @as(u64, @bitCast(opts)),
    });
    delegate.setInstanceVariable("shaderData", buffer);

    const widget_opts: prism.Widget.Options = .{
        .width = .{ .pixels = @floatCast((shader_data.horizontal_pad + shader_data.text_width + shader_data.border_thickness) / 2) },
        .height = .{ .pixels = @floatCast((shader_data.vertical_pad + shader_data.text_height + shader_data.border_thickness) / 2) },
        .click = PrismButtonWidget.click,
        .drag = null,
        .hover = null,
        .user_ctx = delegate.value,
        .presence = PrismButtonWidget.presence,
    };
    const block = Layout.Block.init(.{}, PrismButtonWidget.blockFn) catch return error.PlatformCodeFailed;
    const widget_obj = cocoa.alloc("PrismViewController")
        .msgSend(objc.Object, "initWithZigStruct:size:block:", .{ &widget_opts, @as(u64, @sizeOf(prism.Widget.Options)), block.context });
    return .{ .handle = widget_obj.value };
}

pub fn setup() prism.AppError!void {
    const PrismButtonDelegate = objc.allocateClassPair(
        objc.getClass("NSObject") orelse return error.PlatformCodeFailed,
        "PrismButtonDelegate",
    ) orelse return error.PlatformCodeFailed;
    defer objc.registerClassPair(PrismButtonDelegate);
    if (!(PrismButtonDelegate.addMethod("drawInMTKView:", drawInMTKView) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismButtonDelegate.addMethod("mtkView:drawableSizeWillChange:", drawableSize) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismButtonDelegate.addMethod("initWithPipeline:context:", initWithPipeline) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!PrismButtonDelegate.addIvar("shaderData")) return error.PlatformCodeFailed;
    if (!PrismButtonDelegate.addIvar("pipeline")) return error.PlatformCodeFailed;
    if (!PrismButtonDelegate.addIvar("context")) return error.PlatformCodeFailed;
    if (!PrismButtonDelegate.addIvar("data")) return error.PlatformCodeFailed;
    if (!PrismButtonDelegate.addIvar("text")) return error.PlatformCodeFailed;
    if (!PrismButtonDelegate.addIvar("textTexture")) return error.PlatformCodeFailed;
}

fn initWithPipeline(
    target: objc.c.id,
    _: objc.c.SEL,
    pipeline: objc.c.id,
    context: objc.c.id,
) callconv(.C) objc.c.id {
    const self = objc.Object.fromId(target);
    const pipeline_obj = objc.Object.fromId(pipeline);
    const context_obj = objc.Object.fromId(context);
    self.setInstanceVariable("pipeline", pipeline_obj);
    self.setInstanceVariable("context", context_obj);
    return self.value;
}

fn drawInMTKView(target: objc.c.id, _: objc.c.SEL, view_id: objc.c.id) callconv(.C) void {
    const self = objc.Object.fromId(target);
    const pipeline = self.getInstanceVariable("pipeline");
    const context = self.getInstanceVariable("context");
    const ctx = context.getInstanceVariable("commandQueue");
    const view = objc.Object.fromId(view_id);
    const size = view.getProperty(cocoa.NSSize, "drawableSize");
    const texture = self.getInstanceVariable("textTexture");

    const buffer = ctx.msgSend(objc.Object, "commandBuffer", .{});

    const descriptor = view.getProperty(objc.Object, "currentRenderPassDescriptor");

    const encoder = buffer.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{descriptor});
    encoder.setProperty("viewport", metal.MTLViewport{
        .originX = 0,
        .originY = 0,
        .width = size.width,
        .height = size.height,
        .znear = 0,
        .zfar = 1,
    });

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
        texture,
        @as(u64, 0),
    });
    encoder.msgSend(void, "setFragmentBuffer:offset:atIndex:", .{
        self.getInstanceVariable("shaderData"),
        @as(u64, 0),
        @as(u64, 0),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 3),
        @as(u64, 0),
        @as(u64, 6),
    });

    encoder.msgSend(void, "endEncoding", .{});

    buffer.msgSend(void, "presentDrawable:", .{
        view.getProperty(objc.Object, "currentDrawable"),
    });

    buffer.msgSend(void, "commit", .{});

    const data = self.getInstanceVariable("shaderData");
    const shader_data_ptr = data.msgSend(*anyopaque, "contents", .{});
    const shader_data: *ShaderData = @ptrCast(@alignCast(shader_data_ptr));
    shader_data.frame_nr += 1;
    const range: cocoa.NSRange = .{
        .location = 0,
        .length = @sizeOf(ShaderData),
    };
    data.msgSend(void, "didModifyRange:", .{range});
}

fn drawableSize(_: objc.c.id, _: objc.c.SEL, _: objc.c.id, _: cocoa.NSSize) callconv(.C) void {}

const ShaderData = extern struct {
    bg: [4]f32,
    fg: [4]f32,
    hl_bg: [4]f32,
    hl_fg: [4]f32,
    frame_nr: u32,
    text_width: f32,
    text_height: f32,
    horizontal_pad: f32,
    vertical_pad: f32,
    border_thickness: f32,
    clicked: bool,
    present: bool,
};

const PrismButtonWidget = struct {
    fn click(ctx: ?*anyopaque, _: f64, _: f64, button: prism.MouseButton, is_release: bool) bool {
        const id: objc.c.id = @ptrCast(@alignCast(ctx orelse return true));
        const delegate = objc.Object.fromId(id);
        const options = delegate.getInstanceVariable("data")
            .msgSend(*const anyopaque, "bytes", .{});
        const opts: *const prism.Graphics.PrismButton.Options = @ptrCast(@alignCast(options));
        const data = delegate.getInstanceVariable("shaderData");
        const shader_data_ptr = data.msgSend(*anyopaque, "contents", .{});
        const shader_data: *ShaderData = @ptrCast(@alignCast(shader_data_ptr));
        switch (button) {
            .left => shader_data.clicked = !is_release,
            else => {},
        }
        shader_data.frame_nr = 0;
        const range: cocoa.NSRange = .{
            .location = 0,
            .length = @sizeOf(ShaderData),
        };
        data.msgSend(void, "didModifyRange:", .{range});

        if (!is_release) opts.clickFn(opts.user_data);
        return false;
    }

    fn presence(ctx: ?*anyopaque, is_enter: bool) bool {
        const id: objc.c.id = @ptrCast(@alignCast(ctx orelse return true));
        const delegate = objc.Object.fromId(id);
        const data = delegate.getInstanceVariable("shaderData");
        const shader_data_ptr = data.msgSend(*anyopaque, "contents", .{});
        const shader_data: *ShaderData = @ptrCast(@alignCast(shader_data_ptr));
        shader_data.present = is_enter;
        shader_data.frame_nr = 0;
        const range: cocoa.NSRange = .{
            .location = 0,
            .length = @sizeOf(ShaderData),
        };
        data.msgSend(void, "didModifyRange:", .{range});
        return false;
    }

    fn blockFn(
        _: *const Layout.Block.Context,
        self: objc.c.id,
        new_size: cocoa.NSSize,
        init_view: objc.c.BOOL,
    ) callconv(.C) cocoa.NSSize {
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

        const id: objc.c.id = @ptrCast(@alignCast(options.user_ctx.?));
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
                .msgSend(objc.Object, "initWithFrame:device:", .{ cocoa.NSRect{
                .origin = .{ .x = 0, .y = 0 },
                .size = actual_new_size,
            }, device });
            defer mtkview.msgSend(void, "release", .{});
            view.msgSend(void, "addSubview:", .{mtkview});
            mtkview.setProperty("delegate", delegate.value);
        }
        const view = controller.getInstanceVariable("view");
        view.msgSend(void, "setFrameSize:", .{actual_new_size});
        view.getProperty(objc.Object, "subviews")
            .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)})
            .msgSend(void, "setFrameSize:", .{actual_new_size});
        return actual_new_size;
    }
};

const MTLTextureUsage = packed struct(u64) {
    read: bool,
    write: bool,
    render: bool,
    _unused: u5 = 0,
    pixel_format_view: bool,
    _padding: u55 = 0,
};
