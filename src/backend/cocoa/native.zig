const prism = @import("../../prism.zig");
const cocoa = @import("cocoa.zig");
const Layout = @import("layout.zig");
const objc = @import("zig-objc");

pub const NativeButton = struct {
    pub fn widget(
        options: prism.NativeButton.Options,
    ) prism.AppError!prism.Widget {
        const delegate = cocoa.alloc("PrismNativeButtonDelegate")
            .msgSend(objc.Object, "initWithZigStruct:", .{&options});

        const widget_opts: prism.Widget.Options = .{
            .width = .{ .fraction = 1 },
            .height = .{ .fraction = 1 },
            .click = Widget.click,
            .hover = null,
            .user_ctx = delegate.value,
            .presence = Widget.presence,
            .drag = null,
        };

        const block = Layout.Block.init(.{}, Widget.blockFn) catch return error.PlatformCodeFailed;
        const widget_obj = cocoa.alloc("PrismViewController")
            .msgSend(objc.Object, "initWithZigStruct:size:block:", .{
            &widget_opts,
            @as(u64, @sizeOf(prism.Widget.Options)),
            block.context,
        });
        return .{ .handle = widget_obj.value };
    }

    const Widget = struct {
        fn click(ctx: ?*anyopaque, x: f64, y: f64, button: prism.MouseButton, is_release: bool) bool {
            _ = ctx; // autofix
            _ = x; // autofix
            _ = y; // autofix
            return button == .left and !is_release;
        }

        fn presence(ctx: ?*anyopaque, is_enter: bool) bool {
            const id: objc.c.id = @ptrCast(@alignCast(ctx orelse return true));
            const button_delegate = objc.Object.fromId(id);
            const button = button_delegate.getInstanceVariable("view");
            button.msgSend(void, "highlight:", .{if (is_enter) cocoa.YES else cocoa.NO});
            return false;
        }

        fn blockFn(
            block_ptr: *const Layout.Block.Context,
            self: objc.c.id,
            new_size: cocoa.NSSize,
            init_view: objc.c.BOOL,
        ) callconv(.C) cocoa.NSSize {
            _ = new_size; // autofix
            _ = block_ptr; // autofix
            const controller = objc.Object.fromId(self);
            const opts = controller.getInstanceVariable("data")
                .msgSend(*const anyopaque, "bytes", .{});
            const options: *const prism.Widget.Options = @ptrCast(@alignCast(opts));
            const id: objc.c.id = @ptrCast(@alignCast(options.user_ctx.?));
            const delegate = objc.Object.fromId(id);
            if (init_view == cocoa.YES) {
                const view = cocoa.alloc("PrismView")
                    .msgSend(objc.Object, "initWithZigStruct:size:frame:", .{
                    options,
                    @as(u64, @sizeOf(prism.Widget.Options)),
                    cocoa.NSRect{
                        .origin = .{ .x = 0, .y = 0 },
                        .size = .{ .width = 0, .height = 0 },
                    },
                });
                controller.setInstanceVariable("view", view);
                const button = objc.getClass("NSButton").?
                    .msgSend(objc.Object, "buttonWithTitle:target:action:", .{
                    delegate.getInstanceVariable("title"),
                    delegate.value,
                    objc.sel("click:").value,
                });
                delegate.setInstanceVariable("view", button);
                view.msgSend(void, "addSubview:", .{button});
            }
            const view = controller.getInstanceVariable("view");

            const button = view.getProperty(objc.Object, "subviews")
                .msgSend(objc.Object, "objectAtIndex:", .{@as(u64, 0)});
            const rect = button.getProperty(cocoa.NSRect, "frame");
            view.msgSend(void, "setFrameSize:", .{rect.size});

            return rect.size;
        }
    };

    const Context = struct {
        action: *const fn (?*anyopaque) void,
        ctx: ?*anyopaque,
    };

    fn setup() prism.AppError!void {
        const PrismNativeButtonDelegate = objc.allocateClassPair(
            objc.getClass("NSObject") orelse return error.PlatformCodeFailed,
            "PrismNativeButtonDelegate",
        ) orelse return error.PlatformCodeFailed;
        defer objc.registerClassPair(PrismNativeButtonDelegate);
        if (!(PrismNativeButtonDelegate.addMethod("click:", click) catch return error.PlatformCodeFailed))
            return error.PlatformCodeFailed;
        if (!(PrismNativeButtonDelegate.addMethod("initWithZigStruct:", initWithZigStruct) catch return error.PlatformCodeFailed))
            return error.PlatformCodeFailed;
        if (!PrismNativeButtonDelegate.addIvar("title")) return error.PlatformCodeFailed;
        if (!PrismNativeButtonDelegate.addIvar("context")) return error.PlatformCodeFailed;
        if (!PrismNativeButtonDelegate.addIvar("view")) return error.PlatformCodeFailed;
    }

    fn click(target: objc.c.id, sel: objc.c.SEL, sender: objc.c.id) callconv(.C) void {
        _ = sel; // autofix
        _ = sender; // autofix
        const self = objc.Object.fromId(target);
        const ptr = self.getInstanceVariable("context")
            .msgSend(*const anyopaque, "bytes", .{});
        const context: *const Context = @ptrCast(@alignCast(ptr));
        context.action(context.ctx);
    }

    fn initWithZigStruct(target: objc.c.id, sel: objc.c.SEL, zig_struct: *anyopaque) callconv(.C) objc.c.id {
        _ = sel; // autofix
        const self = objc.Object.fromId(target);
        const ctx: *prism.NativeButton.Options = @ptrCast(@alignCast(zig_struct));
        const context: Context = .{
            .action = ctx.action,
            .ctx = ctx.ctx,
        };
        const data = objc.getClass("NSData").?
            .msgSend(objc.Object, "dataWithBytes:length:", .{
            &context,
            @as(u64, @sizeOf(Context)),
        });
        self.setInstanceVariable("context", data);

        const str = cocoa.NSString(ctx.text);
        self.setInstanceVariable("title", str);
        return self.value;
    }
};

pub fn setup() prism.AppError!void {
    try NativeButton.setup();
}
