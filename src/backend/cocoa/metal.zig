const prism = @import("../../prism.zig");
const cocoa = @import("cocoa.zig");
const objc = @import("zig-objc");
pub const PixelShader = @import("metal/pixel_shader.zig");
pub const PrismButton = @import("metal/prism_button.zig");
pub const Drawing = @import("metal/drawing.zig");

const Graphics = prism.Graphics;

pub fn init() prism.AppError!Graphics {
    try setup();
    return .{
        .handle = MTLCreateSystemDefaultDevice(),
    };
}

pub fn create(device: Graphics) prism.Graphics.Err!prism.Graphics.RenderingContext {
    const device_id: objc.c.id = @ptrCast(@alignCast(device.handle));
    const mtkdevice = objc.Object.fromId(device_id);
    const command_queue = mtkdevice.msgSend(objc.Object, "newCommandQueue", .{});
    const context = cocoa.alloc("PrismGraphicsContext")
        .msgSend(objc.Object, "init", .{});
    context.setInstanceVariable("commandQueue", command_queue);
    const image_context = objc.getClass("CIContext").?
        .msgSend(objc.Object, "contextWithMTLCommandQueue:", .{command_queue});
    context.setInstanceVariable("imageContext", image_context);
    const pipelines = cocoa.alloc("NSMutableArray")
        .msgSend(objc.Object, "init", .{});
    context.setInstanceVariable("apiPipelines", pipelines);
    try PrismButton.compile(context);
    try Drawing.compile(context);
    return .{
        .handle = context.value,
    };
}

pub fn destroy(self: Graphics.RenderingContext) void {
    const context_id: objc.c.id = @ptrCast(@alignCast(self.handle));
    const context = objc.Object.fromId(context_id);
    defer context.msgSend(void, "release", .{});
    context.getInstanceVariable("commandQueue").msgSend(void, "release", .{});
    context.getInstanceVariable("prismButtonPipeline").msgSend(void, "release", .{});
    context.getInstanceVariable("imageContext").msgSend(void, "release", .{});
}

extern "C" fn MTLCreateSystemDefaultDevice() objc.c.id;
pub extern "C" fn CGColorSpaceCreateDeviceRGB() objc.c.id;

pub const MTLViewport = extern struct {
    originX: f64,
    originY: f64,
    width: f64,
    height: f64,
    znear: f64,
    zfar: f64,
};

fn setup() prism.AppError!void {
    {
        const PrismGraphicsContext = objc.allocateClassPair(
            objc.getClass("NSObject") orelse return error.PlatformCodeFailed,
            "PrismGraphicsContext",
        ) orelse return error.PlatformCodeFailed;
        defer objc.registerClassPair(PrismGraphicsContext);
        if (!PrismGraphicsContext.addIvar("commandQueue")) return error.PlatformCodeFailed;
        if (!PrismGraphicsContext.addIvar("prismButtonPipeline")) return error.PlatformCodeFailed;
        if (!PrismGraphicsContext.addIvar("apiPipelines")) return error.PlatformCodeFailed;
        if (!PrismGraphicsContext.addIvar("imageContext")) return error.PlatformCodeFailed;
    }
    try PixelShader.setup();
    try PrismButton.setup();
    try Drawing.setup();
}

pub const ResourceOptions = packed struct(u64) {
    cache_mode: enum(u1) {
        Default,
        WriteCombined,
    },
    _unused: u3 = 0,
    storage_mode: enum(u2) { Shared, Managed, Private, Memoryless },
    _unused_2: u2 = 0,
    hazard_mode: enum(u2) {
        Default,
        Untracked,
        Tracked,
        _unused,
    },
    _padding: u54 = 0,
};
