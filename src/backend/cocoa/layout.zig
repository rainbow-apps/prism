const prism = @import("../../prism.zig");
const cocoa = @import("cocoa.zig");
const objc = @import("zig-objc");

pub fn init() prism.AppError!void {
    const PrismViewController = objc.allocateClassPair(
        objc.getClass("NSObject") orelse return error.PlatformCodeFailed,
        "PrismViewController",
    ) orelse return error.PlatformCodeFailed;
    defer objc.registerClassPair(PrismViewController);
    if (!(PrismViewController.addMethod("initWithZigStruct:size:block:", initWithZigStruct) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!(PrismViewController.addMethod("attemptResizeWithSize:init:", attemptResize) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    if (!PrismViewController.addIvar("data")) return error.PlatformCodeFailed;
    if (!PrismViewController.addIvar("layoutSize")) return error.PlatformCodeFailed;
    if (!PrismViewController.addIvar("layoutBlock")) return error.PlatformCodeFailed;
    if (!PrismViewController.addIvar("view")) return error.PlatformCodeFailed;
}

pub fn create(options: prism.Layout.Options, children: anytype) prism.Layout.Error!prism.Layout {
    const block = Block.init(.{}, (struct {
        fn blockFn(
            block_ptr: *const Block.Context,
            self: objc.c.id,
            new_size: cocoa.NSSize,
            init_view: objc.c.BOOL,
        ) callconv(.C) cocoa.NSSize {
            _ = block_ptr;
            const controller = objc.Object.fromId(self);
            const size = controller.getInstanceVariable("layoutSize");
            const current_size = size.msgSend(cocoa.NSRect, "sizeValue", .{});
            const data = controller.getInstanceVariable("data")
                .msgSend(*anyopaque, "bytes", .{});
            const blk_options: *prism.Layout.Options = @ptrCast(@alignCast(data));

            const actual_new_size: cocoa.NSSize = .{
                .height = switch (blk_options.height) {
                    .fraction => new_size.height,
                    .pixels => |p| p,
                },
                .width = switch (blk_options.width) {
                    .fraction => new_size.width,
                    .pixels => |p| p,
                },
            };

            switch (blk_options.kind) {
                .Box => |box| {
                    const width_trim: f64 = switch (box.margins.left) {
                        .pixels => |p| p,
                        .fraction => |f| actual_new_size.width * f,
                    } + switch (box.margins.right) {
                        .pixels => |p| p,
                        .fraction => |f| actual_new_size * f,
                    };
                    const height_trim: f64 = switch (box.margins.top) {
                        .pixels => |p| p,
                        .fraction => |f| actual_new_size.height * f,
                    } + switch (box.margins.bottom) {
                        .pixels => |p| p,
                        .fraction => |f| actual_new_size.height * f,
                    };
                    const child_size: cocoa.NSSize = .{
                        .width = actual_new_size.width - width_trim,
                        .height = actual_new_size.height - height_trim,
                    };
                    if (child_size.height < 0 or child_size.width < 0) return current_size;
                    const child = controller.getProperty(objc.Object, "childViewControllers")
                        .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)});
                    const new_child_size = child.msgSend(cocoa.NSSize, "attemptResizeWithSize:init:", .{
                        child_size, init_view,
                    });
                    const set_size_to: cocoa.NSSize = .{
                        .width = new_child_size.width + width_trim,
                        .height = new_child_size + height_trim,
                    };
                    if (init_view == cocoa.YES) {
                        const view = cocoa.alloc("NSView")
                            .msgSend(objc.Object, "initWithFrame:", .{
                            cocoa.NSRect{
                                .origin = .{ .x = 0, .y = 0 },
                                .size = set_size_to,
                            },
                        });
                        controller.setInstanceVariable("view", view);
                        const child_view = child.getProperty(objc.Object, "view");
                        view.msgSend(void, "addSubview:", .{child_view});
                    } else {
                        controller.getProperty(objc.Object, "view")
                            .msgSend(void, "setFrameSize:", .{set_size_to});
                    }
                    const new_origin: cocoa.NSPoint = .{
                        .x = switch (box.margins.left) {
                            .pixels => |p| p,
                            .fraction => |f| set_size_to.width * f,
                        },
                        .y = switch (box.margins.bottom) {
                            .pixels => |p| p,
                            .fraction => |f| set_size_to.height * f,
                        },
                    };
                    const child_view = child.getProperty(objc.Object, "view");
                    child_view.msgSend(void, "setFrameOrigin:", .{new_origin});
                    child_view.setProperty("needsDisplay", .{cocoa.YES});
                    size.msgSend(void, "release", .{});
                    const ivar = objc.getClass("NSValue").?
                        .msgSend(objc.Object, "valueWithSize:", .{set_size_to});
                    controller.setInstanceVariable("layoutSize", ivar);
                    return set_size_to;
                },
            }
        }
    }).blockFn) catch return error.PlatformCodeFailed;
    const controller = cocoa.alloc("PrismViewController")
        .msgSend(objc.Object, "initWithZigStruct:size:block:", .{
        &options,
        @sizeOf(prism.Layout.Options),
        block.context,
    });

    const info = @typeInfo(@TypeOf(children));
    comptime {
        @import("std").debug.assert(info == .Struct);
        @import("std").debug.assert(info.Struct.is_tuple);
        if (options.kind == .Box) @import("std").debug.assert(info.Struct.fields.len == 1);
        for (info.Struct.fields) |field| {
            @import("std").debug.assert(field.type == prism.Layout or field.type == prism.Widget);
        }
    }
    for (@typeInfo(@TypeOf(children)).Struct.fields) |field| {
        const layout = @field(children, field.name);
        const layout_id: objc.c.id = @ptrCast(@alignCast(layout.handle));
        const layout_obj = objc.Object.fromId(layout_id);
        controller.msgSend(void, "addChildViewController:", .{layout_obj});
    }

    return .{
        .handle = controller.value,
    };
}

pub fn destroy(self: prism.Layout) void {
    const controller_id: objc.c.id = @ptrCast(@alignCast(self.handle));
    const controller = objc.Object.fromId(controller_id);
    const view = controller.getInstanceVariable("view");
    view.msgSend(void, "release", .{});
    controller.getInstanceVariable("data")
        .msgSend(void, "release", .{});
    const block: Block = .{
        .context = @ptrCast(@alignCast(controller.getInstanceVariable("layoutBlock").value)),
    };
    block.deinit();
    controller.msgSend(void, "release", .{});
}

pub const Block = objc.Block(
    struct {},
    .{ objc.c.id, cocoa.NSSize, objc.c.BOOL },
    cocoa.NSSize,
);

fn initWithZigStruct(
    target: objc.c.id,
    sel: objc.c.SEL,
    zig_struct: *anyopaque,
    size: u64,
    layout_block: objc.c.id,
) callconv(.C) objc.c.id {
    _ = sel;
    const self = objc.Object.fromId(target);
    const data = objc.getClass("NSData").?
        .msgSend(objc.Object, "dataWithBytes:length:", .{
        zig_struct,
        size,
    });
    self.setInstanceVariable("data", data);
    self.setInstanceVariable("layoutBlock", objc.Object.fromId(layout_block));
    const layout_size = objc.getClass("NSValue").?
        .msgSend(objc.Object, "valueWithSize:", .{
        cocoa.NSSize{
            .width = 0,
            .height = 0,
        },
    });
    self.setInstanceVariable("layoutSize", layout_size);
    return self.value;
}

fn attemptResize(
    target: objc.c.id,
    sel: objc.c.SEL,
    new_size: cocoa.NSSize,
    init_view: objc.c.BOOL,
) callconv(.C) cocoa.NSSize {
    _ = sel;
    const self = objc.Object.fromId(target);
    const layout_block = self.getInstanceVariable("layoutBlock");
    const block: Block = .{
        .context = @ptrCast(@alignCast(layout_block.value)),
    };
    return block.invoke(.{ target, new_size, init_view });
}
