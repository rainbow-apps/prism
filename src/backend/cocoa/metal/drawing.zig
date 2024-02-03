const prism = @import("../../../prism.zig");
const objc = @import("zig-objc");
const metal = @import("../metal.zig");
const cocoa = @import("../cocoa.zig");
const Layout = @import("../layout.zig");
const src = @embedFile("drawing.metal");

const RenderStep = enum(u64) {
    point,
    fill,
    line,
};

pub fn setup() prism.AppError!void {
    const PrismDrawingDelegate = objc.allocateClassPair(
        objc.getClass("NSObject") orelse return error.PlatformCodeFailed,
        "PrismDrawingDelegate",
    ) orelse return error.PlatformCodeFailed;
    defer objc.registerClassPair(PrismDrawingDelegate);
    if (!(PrismDrawingDelegate.addMethod("drawInMTKView:", drawInMTKView) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismDrawingDelegate.addMethod("mtkView:drawableSizeWillChange:", drawableSize) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismDrawingDelegate.addMethod("initWithContext:", initWithContext) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!PrismDrawingDelegate.addIvar("context")) return error.PlatformCodeFailed;
    if (!PrismDrawingDelegate.addIvar("commandBuffer")) return error.PlatformCodeFailed;
}

fn unwrap(err_obj: objc.c.id) error{CompilationFailed}!void {
    if (err_obj == cocoa.nil) return;
    const error_str = objc.Object.fromId(err_obj);
    defer error_str.msgSend(void, "release", .{});
    const string = error_str.getProperty(objc.Object, "localizedDescription")
        .getProperty([*:0]const u8, "UTF8String");
    @import("std").debug.print("{s}\n", .{string});
    return error.CompilationFailed;
}

pub fn compile(rendering_context: objc.Object) prism.Graphics.Err!void {
    const command_queue = rendering_context.getInstanceVariable("commandQueue");
    const device = command_queue.getProperty(objc.Object, "device");
    var err_obj: objc.c.id = undefined;
    const lib = library: {
        const opts = cocoa.alloc("MTLCompileOptions")
            .msgSend(objc.Object, "init", .{});
        defer opts.msgSend(void, "release", .{});
        const src_str = cocoa.NSString(src);
        defer src_str.msgSend(void, "release", .{});
        break :library device.msgSend(objc.Object, "newLibraryWithSource:options:error:", .{ src_str, opts, &err_obj });
    };
    defer lib.msgSend(void, "release", .{});
    try unwrap(err_obj);

    err_obj = undefined;
    const pt_desc = desc: {
        const pt_vtx = getFunction(lib, "pointVtxFn");
        defer pt_vtx.msgSend(void, "release", .{});
        const pt_frag = getFunction(lib, "pointFragFn");
        defer pt_frag.msgSend(void, "release", .{});

        const descriptor = cocoa.alloc("MTLRenderPipelineDescriptor")
            .msgSend(objc.Object, "init", .{});
        descriptor.msgSend(void, "reset", .{});
        descriptor.setProperty("vertexFunction", pt_vtx);
        descriptor.setProperty("fragmentFunction", pt_frag);
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
        break :desc descriptor;
    };
    defer pt_desc.msgSend(void, "release", .{});
    const pt_pipeline = device.msgSend(objc.Object, "newRenderPipelineStateWithDescriptor:error:", .{
        pt_desc,
        &err_obj,
    });
    try unwrap(err_obj);
    rendering_context.getInstanceVariable("apiPipelines")
        .msgSend(void, "addObject:", .{pt_pipeline});

    err_obj = undefined;
    const rect_desc = desc: {
        const vtx = getFunction(lib, "rectVtxFn");
        defer vtx.msgSend(void, "release", .{});
        const frag = getFunction(lib, "rectFragFn");
        defer frag.msgSend(void, "release", .{});

        const descriptor = cocoa.alloc("MTLRenderPipelineDescriptor")
            .msgSend(objc.Object, "init", .{});
        descriptor.msgSend(void, "reset", .{});
        descriptor.setProperty("vertexFunction", vtx);
        descriptor.setProperty("fragmentFunction", frag);
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
        break :desc descriptor;
    };
    defer rect_desc.msgSend(void, "release", .{});
    const rect_pipeline = device.msgSend(objc.Object, "newRenderPipelineStateWithDescriptor:error:", .{
        rect_desc,
        &err_obj,
    });
    try unwrap(err_obj);
    rendering_context.getInstanceVariable("apiPipelines")
        .msgSend(void, "addObject:", .{rect_pipeline});

    err_obj = undefined;
    const line_desc = desc: {
        const vtx = getFunction(lib, "lineVtxFn");
        defer vtx.msgSend(void, "release", .{});
        const frag = getFunction(lib, "rectFragFn");
        defer frag.msgSend(void, "release", .{});

        const descriptor = cocoa.alloc("MTLRenderPipelineDescriptor")
            .msgSend(objc.Object, "init", .{});
        descriptor.msgSend(void, "reset", .{});
        descriptor.setProperty("vertexFunction", vtx);
        descriptor.setProperty("fragmentFunction", frag);
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
        break :desc descriptor;
    };
    defer line_desc.msgSend(void, "release", .{});
    const line_pipeline = device.msgSend(objc.Object, "newRenderPipelineStateWithDescriptor:error:", .{
        line_desc,
        &err_obj,
    });
    try unwrap(err_obj);
    rendering_context.getInstanceVariable("apiPipelines")
        .msgSend(void, "addObject:", .{line_pipeline});
}

fn transformMatrix(bounds: [2]f32) [4][4]f32 {
    return .{
        .{ 4 / bounds[0], 0, 0, 0 },
        .{ 0, -4 / bounds[1], 0, 0 },
        .{ 1, 1, 1, 0 },
        .{ -1, 1, 0, 1 },
    };
}

const VertexInner = extern struct {
    color: [4]f32,
    position: [4]f32,
};

const RectLineInner = extern struct {
    color: [4]f32,
    origin: [2]f32,
    opposite: [2]f32,
    thickness: [4]f32,
};

pub fn rect(wid: prism.Widget, data: prism.Graphics.Drawing.RectLineData) void {
    const encoder, const size = getEncoderAndSize(wid, .line);
    const matrix = transformMatrix(size);
    const color: [4]f32 = .{ data.color.r, data.color.g, data.color.b, data.color.a };
    const s: f32 = if (data.origin.y > data.opposite.y) -1 else 1;
    const pts: [4]RectLineInner = .{
        .{
            .color = color,
            .origin = .{ data.origin.x, data.origin.y - s * data.thickness },
            .opposite = .{ data.origin.x, data.opposite.y + s * data.thickness },
            .thickness = .{ data.thickness, 0, 0, 0 },
        },
        .{
            .color = color,
            .origin = .{ data.origin.x, data.opposite.y },
            .opposite = .{ data.opposite.x, data.opposite.y },
            .thickness = .{ data.thickness, 0, 0, 0 },
        },
        .{
            .color = color,
            .origin = .{ data.opposite.x, data.opposite.y + s * data.thickness },
            .opposite = .{ data.opposite.x, data.origin.y - s *  data.thickness },
            .thickness = .{ data.thickness, 0, 0, 0 },
        },
        .{
            .color = color,
            .origin = .{ data.opposite.x, data.origin.y },
            .opposite = .{ data.origin.x, data.origin.y },
            .thickness = .{ data.thickness, 0, 0, 0 },
        },
    };
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&pts)),
        @as(u64, @sizeOf([4]RectLineInner)),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&matrix)),
        @as(u64, @sizeOf(@TypeOf(matrix))),
        @as(u64, 1),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 3),
        @as(u64, 0),
        @as(u64, 6 * 4),
    });
    encoder.msgSend(void, "endEncoding", .{});
}

pub fn rects(wid: prism.Widget, data: []prism.Graphics.Drawing.RectLineData) void {
    var pt_buf: [4 * 256]RectLineInner = undefined;
    var idx: usize = 0;
    while (idx < data.len) {
        const encoder, const size = getEncoderAndSize(wid, .line);
        const matrix = transformMatrix(size);
        const end: usize = @min(256, data.len - idx);
        for (0..end, data[idx..][0..end]) |i, p| {
            const color: [4]f32 = .{ p.color.r, p.color.g, p.color.b, p.color.a };
            const s: f32 = if (p.origin.y > p.opposite.y) -1 else 1;
            pt_buf[i * 4 ..][0..4].* = .{
                .{
                    .color = color,
                    .origin = .{ p.origin.x, p.origin.y - s * p.thickness },
                    .opposite = .{ p.origin.x, p.opposite.y + s * p.thickness },
                    .thickness = .{ p.thickness, 0, 0, 0 },
                },
                .{
                    .color = color,
                    .origin = .{ p.origin.x, p.opposite.y },
                    .opposite = .{ p.opposite.x, p.opposite.y },
                    .thickness = .{ p.thickness, 0, 0, 0 },
                },
                .{
                    .color = color,
                    .origin = .{ p.opposite.x, p.opposite.y + s * p.thickness },
                    .opposite = .{ p.opposite.x, p.origin.y - s * p.thickness },
                    .thickness = .{ p.thickness, 0, 0, 0 },
                },
                .{
                    .color = color,
                    .origin = .{ p.opposite.x, p.origin.y },
                    .opposite = .{ p.origin.x, p.origin.y },
                    .thickness = .{ p.thickness, 0, 0, 0 },
                },
            };
        }
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(pt_buf[0 .. 4 * end].ptr)),
            @as(u64, end * @sizeOf([4]RectLineInner)),
            @as(u64, 0),
        });
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(&matrix)),
            @as(u64, @sizeOf(@TypeOf(matrix))),
            @as(u64, 1),
        });
        encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
            @as(u64, 3),
            @as(u64, 0),
            @as(u64, 6 * 4 * end),
        });
        encoder.msgSend(void, "endEncoding", .{});
        idx += end;
    }
}

pub fn line(wid: prism.Widget, data: prism.Graphics.Drawing.RectLineData) void {
    const encoder, const size = getEncoderAndSize(wid, .line);
    const matrix = transformMatrix(size);
    const pts: RectLineInner = .{
        .color = .{ data.color.r, data.color.g, data.color.b, data.color.a },
        .origin = .{ data.origin.x, data.origin.y },
        .opposite = .{ data.opposite.x, data.opposite.y },
        .thickness = .{ data.thickness, 0, 0, 0 },
    };
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&pts)),
        @as(u64, @sizeOf(RectLineInner)),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&matrix)),
        @as(u64, @sizeOf(@TypeOf(matrix))),
        @as(u64, 1),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 3),
        @as(u64, 0),
        @as(u64, 6),
    });
    encoder.msgSend(void, "endEncoding", .{});
}

pub fn lines(wid: prism.Widget, data: []prism.Graphics.Drawing.RectLineData) void {
    var pt_buf: [1024]RectLineInner = undefined;
    var idx: usize = 0;
    while (idx < data.len) {
        const encoder, const size = getEncoderAndSize(wid, .line);
        const matrix = transformMatrix(size);
        const end: usize = @min(1024, data.len - idx);
        for (0..end, data[idx..][0..end]) |i, p| {
            pt_buf[i] = .{
                .color = .{ p.color.r, p.color.g, p.color.b, p.color.a },
                .origin = .{ p.origin.x, p.origin.y },
                .opposite = .{ p.opposite.x, p.opposite.y },
                .thickness = .{ p.thickness, 0, 0, 0 },
            };
        }
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(pt_buf[0..end].ptr)),
            @as(u64, end * @sizeOf(RectLineInner)),
            @as(u64, 0),
        });
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(&matrix)),
            @as(u64, @sizeOf(@TypeOf(matrix))),
            @as(u64, 1),
        });
        encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
            @as(u64, 3),
            @as(u64, 0),
            @as(u64, 6 * end),
        });
        encoder.msgSend(void, "endEncoding", .{});
        idx += end;
    }
}

pub fn tri(wid: prism.Widget, data: [3]prism.Graphics.Drawing.VertexData) void {
    const encoder, const size = getEncoderAndSize(wid, .fill);
    const matrix = transformMatrix(size);
    const pts: [3]VertexInner = .{
        .{
            .color = .{ data[0].color.r, data[0].color.g, data[0].color.b, data[0].color.a },
            .position = .{ data[0].point.x, data[0].point.y, 0, 0 },
        },
        .{
            .color = .{ data[1].color.r, data[1].color.g, data[1].color.b, data[1].color.a },
            .position = .{ data[1].point.x, data[1].point.y, 0, 0 },
        },
        .{
            .color = .{ data[2].color.r, data[2].color.g, data[2].color.b, data[2].color.a },
            .position = .{ data[2].point.x, data[2].point.y, 0, 0 },
        },
    };
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&pts)),
        @as(u64, 3 * @sizeOf(VertexInner)),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&matrix)),
        @as(u64, @sizeOf(@TypeOf(matrix))),
        @as(u64, 1),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 3),
        @as(u64, 0),
        @as(u64, 3),
    });
    encoder.msgSend(void, "endEncoding", .{});
}

pub fn mesh(wid: prism.Widget, data: []prism.Graphics.Drawing.VertexData) void {
    var pt_buf: [3 * 256]VertexInner = undefined;
    var idx: usize = 0;
    while (idx < data.len) {
        const encoder, const size = getEncoderAndSize(wid, .fill);
        const matrix = transformMatrix(size);
        const end: usize = @min(3 * 256, data.len - idx);
        vertexInnerFromVertex(data[idx..][0..end], pt_buf[0..end]);
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(pt_buf[0..end].ptr)),
            @as(u64, end * @sizeOf(VertexInner)),
            @as(u64, 0),
        });
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(&matrix)),
            @as(u64, @sizeOf(@TypeOf(matrix))),
            @as(u64, 1),
        });
        encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
            @as(u64, 3),
            @as(u64, 0),
            @as(u64, end),
        });  
        encoder.msgSend(void, "endEncoding", .{});
        idx += end;
    }
}

pub fn quad(wid: prism.Widget, data: [4]prism.Graphics.Drawing.VertexData) void {
    const encoder, const size = getEncoderAndSize(wid, .fill);
    const matrix = transformMatrix(size);
    const pts: [4]VertexInner = .{
        .{
            .color = .{ data[0].color.r, data[0].color.g, data[0].color.b, data[0].color.a },
            .position = .{ data[0].point.x, data[0].point.y, 0, 0 },
        },
        .{
            .color = .{ data[1].color.r, data[1].color.g, data[1].color.b, data[1].color.a },
            .position = .{ data[1].point.x, data[1].point.y, 0, 0 },
        },
        .{
            .color = .{ data[2].color.r, data[2].color.g, data[2].color.b, data[2].color.a },
            .position = .{ data[2].point.x, data[2].point.y, 0, 0 },
        },
        .{
            .color = .{ data[3].color.r, data[3].color.g, data[3].color.b, data[3].color.a },
            .position = .{ data[3].point.x, data[3].point.y, 0, 0 },
        },
    };
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&pts)),
        @as(u64, 6 * @sizeOf(VertexInner)),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&matrix)),
        @as(u64, @sizeOf(@TypeOf(matrix))),
        @as(u64, 1),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 4),
        @as(u64, 0),
        @as(u64, 4),
    });
    encoder.msgSend(void, "endEncoding", .{});
}

pub fn rect_fill(wid: prism.Widget, data: prism.Graphics.Drawing.RectFillData) void {
    const encoder, const size = getEncoderAndSize(wid, .fill);
    const matrix = transformMatrix(size);

    const color: [4]f32 = .{ data.color.r, data.color.g, data.color.b, data.color.a };
    const pts: [6]VertexInner = .{
        .{ .color = color, .position = .{ data.origin.x, data.origin.y, 0, 0 } },
        .{ .color = color, .position = .{ data.origin.x, data.opposite.y, 0, 0 } },
        .{ .color = color, .position = .{ data.opposite.x, data.opposite.y, 0, 0 } },
        .{ .color = color, .position = .{ data.origin.x, data.origin.y, 0, 0 } },
        .{ .color = color, .position = .{ data.opposite.x, data.origin.y, 0, 0 } },
        .{ .color = color, .position = .{ data.opposite.x, data.opposite.y, 0, 0 } },
    };
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&pts)),
        @as(u64, 6 * @sizeOf(VertexInner)),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&matrix)),
        @as(u64, @sizeOf(@TypeOf(matrix))),
        @as(u64, 1),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 3),
        @as(u64, 0),
        @as(u64, 6),
    });
    encoder.msgSend(void, "endEncoding", .{});
}

pub fn rects_fill(wid: prism.Widget, data: []prism.Graphics.Drawing.RectFillData) void {
    var pt_buf: [6 * 256]VertexInner = undefined;
    var idx: usize = 0;
    while (idx < data.len) {
        const encoder, const size = getEncoderAndSize(wid, .fill);
        const matrix = transformMatrix(size);
        const end: usize = @min(256, data.len - idx);
        for (0..end, data[idx..][0..end]) |i, p| {
            const color: [4]f32 = .{ p.color.r, p.color.g, p.color.b, p.color.a };
            pt_buf[i * 6 ..][0..6].* = .{
                .{ .color = color, .position = .{ p.origin.x, p.origin.y, 0, 0 } },
                .{ .color = color, .position = .{ p.opposite.x, p.origin.y, 0, 0 } },
                .{ .color = color, .position = .{ p.opposite.x, p.opposite.y, 0, 0 } },
                .{ .color = color, .position = .{ p.origin.x, p.origin.y, 0, 0 } },
                .{ .color = color, .position = .{ p.origin.x, p.opposite.y, 0, 0 } },
                .{ .color = color, .position = .{ p.opposite.x, p.opposite.y, 0, 0 } },
            };
        }
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(pt_buf[0 .. 6 * end].ptr)),
            @as(u64, end * @sizeOf(PointInner)),
            @as(u64, 0),
        });
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(&matrix)),
            @as(u64, @sizeOf(@TypeOf(matrix))),
            @as(u64, 1),
        });
        encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
            @as(u64, 0),
            @as(u64, 0),
            @as(u64, 6 * end),
        });
        encoder.msgSend(void, "endEncoding", .{});
        idx += end;
    }
}

const PointInner = extern struct {
    color: [4]f32,
    position: [2]f32,
    size: f32,
};

pub fn point(wid: prism.Widget, point_data: prism.Graphics.Drawing.PointData) void {
    const encoder, const size = getEncoderAndSize(wid, .point);
    const matrix = transformMatrix(size);

    const pt: PointInner = .{
        .color = .{ point_data.color.r, point_data.color.g, point_data.color.b, point_data.color.a },
        .position = .{ point_data.point.x, point_data.point.y },
        .size = point_data.size,
    };

    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&pt)),
        @as(u64, @sizeOf(PointInner)),
        @as(u64, 0),
    });
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
        @as([*]const u8, @ptrCast(&matrix)),
        @as(u64, @sizeOf(@TypeOf(matrix))),
        @as(u64, 1),
    });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
        @as(u64, 0),
        @as(u64, 0),
        @as(u64, 1),
    });
    encoder.msgSend(void, "endEncoding", .{});
}

pub fn points(wid: prism.Widget, point_data: []prism.Graphics.Drawing.PointData) void {
    var pt_buf: [1024]PointInner = undefined;
    var idx: usize = 0;
    while (idx < point_data.len) {
        const encoder, const size = getEncoderAndSize(wid, .point);
        const matrix = transformMatrix(size);
        const end: usize = @min(1024, point_data.len - idx);
        for (0..end, point_data[idx..][0..end]) |i, p| {
            pt_buf[i] = .{
                .color = .{ p.color.r, p.color.g, p.color.b, p.color.a },
                .position = .{ p.point.x, p.point.y },
                .size = p.size,
            };
        }
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(pt_buf[0..end].ptr)),
            @as(u64, end * @sizeOf(PointInner)),
            @as(u64, 0),
        });
        encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{
            @as([*]const u8, @ptrCast(&matrix)),
            @as(u64, @sizeOf(@TypeOf(matrix))),
            @as(u64, 1),
        });
        encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{
            @as(u64, 0),
            @as(u64, 0),
            @as(u64, end),
        });
        encoder.msgSend(void, "endEncoding", .{});
        idx += end;
    }
}

pub fn redisplay(wid: prism.Widget) void {
    const view = getView(wid);
    view.msgSend(void, "draw", .{});
}

const Options = struct {
    options: prism.Widget.Options,
    delegate: ?*anyopaque,
};

pub fn widget(
    context: prism.Graphics.RenderingContext,
    options: prism.Widget.Options,
) prism.AppError!prism.Widget {
    const ctx_id: objc.c.id = @ptrCast(@alignCast(context.handle));
    const delegate = cocoa.alloc("PrismDrawingDelegate")
        .msgSend(objc.Object, "initWithContext:", .{ctx_id});

    const true_opts: Options = .{
        .options = options,
        .delegate = delegate.value,
    };

    const block = Layout.Block.init(.{}, blockFn) catch return error.PlatformCodeFailed;
    const widget_obj = cocoa.alloc("PrismViewController")
        .msgSend(objc.Object, "initWithZigStruct:size:block:", .{
        &true_opts,
        @as(u64, @sizeOf(Options)),
        block.context,
    });
    return .{ .handle = widget_obj.value };
}

fn drawInMTKView(target: objc.c.id, _: objc.c.SEL, view_id: objc.c.id) callconv(.C) void {
    const self = objc.Object.fromId(target);
    const buffer = self.getInstanceVariable("commandBuffer");
    if (buffer.value != cocoa.nil) {
        buffer.msgSend(void, "presentDrawable:", .{objc.Object.fromId(view_id)
            .getProperty(objc.Object, "currentDrawable")});
        buffer.msgSend(void, "commit", .{});
    }
    self.setInstanceVariable("commandBuffer", objc.Object.fromId(cocoa.nil));
}

fn drawableSize(_: objc.c.id, _: objc.c.SEL, _: objc.c.id, _: cocoa.NSSize) callconv(.C) void {}

fn initWithContext(target: objc.c.id, _: objc.c.SEL, context: objc.c.id) callconv(.C) objc.c.id {
    const self = objc.Object.fromId(target);
    const context_obj = objc.Object.fromId(context);
    self.setInstanceVariable("context", context_obj);
    return self.value;
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
    const options: *const Options = @ptrCast(@alignCast(opts));
    const actual_new_size: cocoa.NSSize = .{
        .width = switch (options.options.width) {
            .fraction => |f| new_size.width * f,
            .pixels => |p| p,
        },
        .height = switch (options.options.height) {
            .fraction => |f| new_size.height * f,
            .pixels => |p| p,
        },
    };
    const id: objc.c.id = @ptrCast(@alignCast(options.delegate.?));
    const delegate = objc.Object.fromId(id);
    const device = delegate.getInstanceVariable("context")
        .getInstanceVariable("commandQueue")
        .getProperty(objc.Object, "device");
    if (init_view == cocoa.YES) {
        const view = cocoa.alloc("PrismView")
            .msgSend(objc.Object, "initWithZigStruct:size:frame:", .{
            &options.options,
            @as(u64, @sizeOf(prism.Widget.Options)),
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
        view.msgSend(void, "addSubview:", .{mtkview});
        mtkview.setProperty("delegate", delegate);
        mtkview.setProperty("framebufferOnly", cocoa.NO);
        mtkview.setProperty("paused", cocoa.YES);
    } else {
        const view = controller.getInstanceVariable("view");
        view.msgSend(void, "setFrameSize:", .{actual_new_size});
        view.getProperty(objc.Object, "subview")
            .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)})
            .msgSend(void, "setFrameSize:", .{actual_new_size});
    }
    return actual_new_size;
}

fn getDelegate(wid: prism.Widget) objc.Object {
    const c_id: objc.c.id = @ptrCast(@alignCast(wid.handle));
    const controller = objc.Object.fromId(c_id);
    const opts = controller.getInstanceVariable("data")
        .msgSend(*const anyopaque, "bytes", .{});
    const options: *const Options = @ptrCast(@alignCast(opts));
    const id: objc.c.id = @ptrCast(@alignCast(options.delegate));
    return objc.Object.fromId(id);
}

fn getView(wid: prism.Widget) objc.Object {
    const controller_id: objc.c.id = @ptrCast(@alignCast(wid.handle));
    return objc.Object.fromId(controller_id)
        .getInstanceVariable("view")
        .getProperty(objc.Object, "subviews")
        .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)});
}

fn getEncoderAndSize(wid: prism.Widget, kind: RenderStep) struct { objc.Object, [2]f32 } {
    const delegate = getDelegate(wid);
    const view = getView(wid);

    const descriptor = view.getProperty(objc.Object, "currentRenderPassDescriptor");
    const buffer = buffer: {
        const buf = delegate.getInstanceVariable("commandBuffer");
        if (buf.value != cocoa.nil) {
            break :buffer buf;
        }
        const buffer = delegate.getInstanceVariable("context")
            .getInstanceVariable("commandQueue")
            .msgSend(objc.Object, "commandBuffer", .{});
        delegate.setInstanceVariable("commandBuffer", buffer);
        break :buffer buffer;
    };
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

    const pipeline = delegate.getInstanceVariable("context")
        .getInstanceVariable("apiPipelines")
        .msgSend(objc.Object, "objectAtIndex:", .{@intFromEnum(kind)});
    encoder.setProperty("renderPipelineState", pipeline);
    return .{ encoder, .{ @floatCast(size.width), @floatCast(size.height) } };
}

fn getFunction(lib: objc.Object, fn_name: [:0]const u8) objc.Object {
    const v_n = cocoa.NSString(fn_name);
    defer v_n.msgSend(void, "release", .{});
    return lib.msgSend(objc.Object, "newFunctionWithName:", .{v_n});
}

fn vertexInnerFromVertex(in: []const prism.Graphics.Drawing.VertexData, out: []VertexInner) void {
    for (in, out) |i, *o| {
        o.color = .{ i.color.r, i.color.g, i.color.b, i.color.a };
        o.position = .{ i.point.x, i.point.y, 0, 0 };
    }
}
