const prism = @import("../../prism.zig");
const cocoa = @import("cocoa.zig");
const objc = @import("zig-objc");

pub fn init() prism.AppError!void {
    {
        const PrismViewController = objc.allocateClassPair(
            objc.getClass("NSObject") orelse return error.PlatformCodeFailed,
            "PrismViewController",
        ) orelse return error.PlatformCodeFailed;
        defer objc.registerClassPair(PrismViewController);
        if (!(PrismViewController.addMethod("initWithZigStruct:size:block:", initWithZigStruct) catch return error.PlatformCodeFailed))
            return error.PlatformCodeFailed;
        if (!(PrismViewController.addMethod("attemptResizeWithSize:init:", attemptResize) catch return error.PlatformCodeFailed))
            return error.PlatformCodeFailed;
        if (!(PrismViewController.addMethod("childViewControllers", childViewControllers) catch return error.PlatformCodeFailed))
            return error.PlatformCodeFailed;
        if (!(PrismViewController.addMethod("addChildViewController:", addChildViewController) catch return error.PlatformCodeFailed))
            return error.PlatformCodeFailed;
        if (!PrismViewController.addIvar("data")) return error.PlatformCodeFailed;
        if (!PrismViewController.addIvar("layoutBlock")) return error.PlatformCodeFailed;
        if (!PrismViewController.addIvar("children")) return error.PlatformCodeFailed;
        if (!PrismViewController.addIvar("view")) return error.PlatformCodeFailed;
    }
}

pub fn create(options: prism.Layout.Options, children: anytype) prism.Layout.Error!prism.Layout {
    const block = switch (options) {
        .Box => Block.init(.{}, boxBlockFn) catch return error.PlatformCodeFailed,
        .Horizontal, .Vertical => Block.init(.{}, horizontalVerticalBlockFn) catch return error.PlatformCodeFailed,
    };
    const controller = cocoa.alloc("PrismViewController")
        .msgSend(objc.Object, "initWithZigStruct:size:block:", .{
        &options,
        @as(u64, @sizeOf(prism.Layout.Options)),
        block.context,
    });

    const info = @typeInfo(@TypeOf(children));
    comptime {
        @import("std").debug.assert(info == .Struct);
        @import("std").debug.assert(info.Struct.is_tuple);
        for (info.Struct.fields) |field| {
            @import("std").debug.assert(field.type == prism.Layout or field.type == prism.Widget);
        }
    }
    if (options == .Box) @import("std").debug.assert(info.Struct.fields.len == 1);
    inline for (info.Struct.fields) |field| {
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
    var block: Block = .{
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
    const children = cocoa.alloc("NSMutableArray")
        .msgSend(objc.Object, "init", .{});
    self.setInstanceVariable("children", children);
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

fn childViewControllers(
    target: objc.c.id,
    sel: objc.c.SEL,
) callconv(.C) objc.c.id {
    _ = sel; // autofix
    const self = objc.Object.fromId(target);
    const children = self.getInstanceVariable("children");
    return children.value;
}

fn addChildViewController(
    target: objc.c.id,
    sel: objc.c.SEL,
    child: objc.c.id,
) callconv(.C) void {
    _ = sel; // autofix
    const self = objc.Object.fromId(target);
    const children = self.getInstanceVariable("children");
    children.msgSend(void, "addObject:", .{child});
}

fn boxBlockFn(
    block_ptr: *const Block.Context,
    self: objc.c.id,
    new_size: cocoa.NSSize,
    init_view: objc.c.BOOL,
) callconv(.C) cocoa.NSSize {
    _ = block_ptr; // autofix
    const controller = objc.Object.fromId(self);
    const data = controller.getInstanceVariable("data")
        .msgSend(*const anyopaque, "bytes", .{});
    const options: *const prism.Layout.Options = @ptrCast(@alignCast(data));
    const child = controller.msgSend(objc.Object, "childViewControllers", .{})
        .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)});
    const new_child_size = child.msgSend(cocoa.NSSize, "attemptResizeWithSize:init:", .{
        new_size, init_view,
    });
    const width_trim: f64 = switch (options.Box.margins.left) {
        .pixels => |p| p,
        .fraction => |f| new_child_size.width * f,
    } + switch (options.Box.margins.right) {
        .pixels => |p| p,
        .fraction => |f| new_child_size.height * f,
    };
    const height_trim: f64 = switch (options.Box.margins.top) {
        .pixels => |p| p,
        .fraction => |f| new_child_size.height * f,
    } + switch (options.Box.margins.bottom) {
        .pixels => |p| p,
        .fraction => |f| new_child_size.height * f,
    };
    const set_size_to: cocoa.NSSize = .{
        .width = new_child_size.width + width_trim,
        .height = new_child_size.height + height_trim,
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
        const child_view = child.getInstanceVariable("view");
        view.msgSend(void, "addSubview:", .{child_view});
    } else {
        controller.getInstanceVariable("view")
            .msgSend(void, "setFrameSize:", .{set_size_to});
    }
    const new_origin: cocoa.NSPoint = .{
        .x = switch (options.Box.margins.left) {
            .pixels => |p| p,
            .fraction => |f| set_size_to.width * f,
        },
        .y = switch (options.Box.margins.bottom) {
            .pixels => |p| p,
            .fraction => |f| set_size_to.height * f,
        },
    };
    const child_view = child.getInstanceVariable("view");
    child_view.msgSend(void, "setFrameOrigin:", .{new_origin});
    child_view.setProperty("needsDisplay", .{cocoa.YES});
    return set_size_to;
}

fn horizontalVerticalBlockFn(
    _: *const Block.Context,
    self: objc.c.id,
    in_size: cocoa.NSSize,
    init_view: objc.c.BOOL,
) callconv(.C) cocoa.NSSize {
    const controller = objc.Object.fromId(self);
    const data = controller.getInstanceVariable("data")
        .msgSend(*const anyopaque, "bytes", .{});
    const options: *const prism.Layout.Options = @ptrCast(@alignCast(data));
    const children = controller.msgSend(objc.Object, "childViewControllers", .{});
    var size: cocoa.NSSize = .{ .height = 0, .width = 0 };

    const new_size: cocoa.NSSize = .{
        .height = switch (options.*) {
            .Box => unreachable,
            .Horizontal => in_size.height,
            .Vertical => |o| switch (o.container_size) {
                .fraction => |f| in_size.height * f,
                .pixels => |p| p,
            },
        },
        .width = switch (options.*) {
            .Box => unreachable,
            .Horizontal => |o| switch (o.container_size) {
                .fraction => |f| in_size.width * f,
                .pixels => |p| p,
            },
            .Vertical => in_size.width,
        },
    };

    const count = children.getProperty(u64, "count");
    for (0..@intCast(count)) |idx| {
        const object = children.msgSend(objc.Object, "objectAtIndex:", .{@as(u64, @intCast(idx))});
        const got_size = object.msgSend(cocoa.NSSize, "attemptResizeWithSize:init:", .{
            new_size,
            init_view,
        });
        switch (options.*) {
            .Box => unreachable,
            .Horizontal => |o| {
                const space = switch (o.spacing) {
                    .fraction => |f| new_size.width * f,
                    .pixels => |p| p,
                };
                if (idx > 0) size.width += space;
                size.width += got_size.width;
                if (got_size.height > size.height)
                    size.height = got_size.height;
            },
            .Vertical => |o| {
                const space = switch (o.spacing) {
                    .fraction => |f| new_size.height * f,
                    .pixels => |p| p,
                };
                if (idx > 0) size.height += space;
                size.height += got_size.height;
                if (got_size.width > size.width)
                    size.width = got_size.width;
            },
        }
    }

    const ret_size: cocoa.NSSize = .{
        .width = switch (options.*) {
            .Box => unreachable,
            .Horizontal => if (new_size.width > size.width) new_size.width else size.width,
            .Vertical => size.width,
        },
        .height = switch (options.*) {
            .Box => unreachable,
            .Horizontal => size.height,
            .Vertical => if (new_size.height > size.height) new_size.height else size.height,
        },
    };

    if (init_view == cocoa.YES) {
        const view = cocoa.alloc("NSView")
            .msgSend(objc.Object, "initWithFrame:", .{
            cocoa.NSRect{
                .origin = .{ .x = 0, .y = 0 },
                .size = ret_size,
            },
        });
        controller.setInstanceVariable("view", view);
        for (0..@intCast(count)) |idx| {
            const child = children.msgSend(objc.Object, "objectAtIndex:", .{@as(u64, @intCast(idx))});
            const child_view = child.getInstanceVariable("view");
            view.msgSend(void, "addSubview:", .{child_view});
        }
    } else {
        controller.getInstanceVariable("view")
            .msgSend(void, "setFrameSize:", .{ret_size});
    }

    var position: f64 = 0;

    const spacing = switch (options.*) {
        .Box => unreachable,
        .Horizontal => |o| switch (o.spacing) {
            .fraction => |f| new_size.width * f,
            .pixels => |p| p,
        },
        .Vertical => |o| switch (o.spacing) {
            .fraction => |f| new_size.height * f,
            .pixels => |p| p,
        },
    };

    for (0..@intCast(count)) |idx| {
        const object = children.msgSend(objc.Object, "objectAtIndex:", .{@as(u64, @intCast(idx))});
        const view = object.getInstanceVariable("view");
        const frame = view.getProperty(cocoa.NSRect, "frame");
        switch (options.*) {
            .Box => unreachable,
            .Horizontal => |o| {
                if (idx == 0) {
                    switch (o.content_alignment) {
                        .left => position = 0,
                        .right => position = ret_size.width - size.width,
                        .center => position = (ret_size.width - size.width) / 2,
                    }
                } else {
                    position += spacing;
                }
                const y: f64 = switch (o.child_alignment) {
                    .top => size.height - frame.size.height,
                    .center => (size.height - frame.size.height) / 2,
                    .bottom => 0,
                };
                const point: cocoa.NSPoint = .{
                    .x = position,
                    .y = y,
                };
                view.msgSend(void, "setFrameOrigin:", .{point});
                position += frame.size.width;
            },
            .Vertical => |o| {
                if (idx == 0) {
                    switch (o.content_alignment) {
                        .top => position = ret_size.height,
                        .bottom => position = size.height,
                        .center => position = size.height + (ret_size.height - size.height) / 2,
                    }
                } else {
                    position -= spacing;
                }
                position -= frame.size.height;
                const x: f64 = switch (o.child_alignment) {
                    .right => size.width - frame.size.width,
                    .center => (size.width - frame.size.width) / 2,
                    .left => 0,
                };
                const point: cocoa.NSPoint = .{
                    .x = x,
                    .y = position,
                };
                view.msgSend(void, "setFrameOrigin:", .{point});
            },
        }
    }
    return ret_size;
}
