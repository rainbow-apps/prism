const prism = @import("../../prism.zig");
const cocoa = @import("cocoa.zig");
const objc = @import("zig-objc");

pub fn init() prism.AppError!void {
    const PrismView = objc.allocateClassPair(
        objc.getClass("NSView") orelse return error.PlatformCodeFailed,
        "PrismView",
    ) orelse return error.PlatformCodeFailed;
    defer objc.registerClassPair(PrismView);
    if (!(PrismView.addMethod("initWithZigStruct:size:frame:", initWithZigStruct) catch return error.PlatformCodeFailed))
        return error.PlatformCodeFailed;
    PrismView.replaceMethod("mouseMoved:", mouseMoved);
    PrismView.replaceMethod("mouseDown:", mouseClicked);
    PrismView.replaceMethod("rightMouseDown:", mouseClicked);
    PrismView.replaceMethod("otherMouseDown:", mouseClicked);
    PrismView.replaceMethod("mouseUp:", mouseClicked);
    PrismView.replaceMethod("rightMouseUp:", mouseClicked);
    PrismView.replaceMethod("otherMouseUp:", mouseClicked);
    PrismView.replaceMethod("mouseDragged:", mouseDragged);
    PrismView.replaceMethod("rightMouseDragged:", mouseDragged);
    PrismView.replaceMethod("otherMouseDragged:", mouseDragged);
    PrismView.replaceMethod("mouseEntered:", mousePresence);
    PrismView.replaceMethod("mouseExited:", mousePresence);
    PrismView.replaceMethod("acceptsFirstResponder", acceptsFirstResponder);
    if (!PrismView.addIvar("options")) return error.PlatformCodeFailed;
    if (!PrismView.addIvar("context")) return error.PlatformCodeFailed;
}

pub fn destroy(self: prism.Widget) void {
    const self_id: objc.c.id = @ptrCast(@alignCast(self.handle));
    const widget = objc.Object.fromId(self_id);
    const opts = widget.getInstanceVariable("options");
    defer opts.msgSend(void, "release", .{});
    const ctx = widget.getInstanceVariable("context");
    defer ctx.msgSend(void, "release", .{});
    widget.msgSend(void, "release", .{});
}

fn initWithZigStruct(
    target: objc.c.id,
    _: objc.c.SEL,
    zig_struct: *const anyopaque,
    size: u64,
    frame: cocoa.NSRect,
) callconv(.C) objc.c.id {
    const self = objc.Object.fromId(target);
    const ptr: *const prism.Widget.Options = @ptrCast(@alignCast(zig_struct));
    const data = objc.getClass("NSData").?
        .msgSend(objc.Object, "dataWithBytes:length:", .{
            ptr,
            size,
    });
    self.setInstanceVariable("options", data);

    const ctxt: objc.c.id = if (ptr.user_ctx) |ctx| @ptrCast(@alignCast(ctx)) else cocoa.nil;
    self.setInstanceVariable("context", .{ .value = ctxt });

    self.msgSendSuper(objc.getClass("NSView").?, void, "initWithFrame:", .{frame});

    if (ptr.hover != null or ptr.presence != null) {
        const area_options: cocoa.NSTrackingAreaOptions = .{
            .active_always = false,
            .active_in_active_app = false,
            .active_in_key_window = true,
            .active_when_first_responder = true,
            .assume_inside = false,
            .enabled_during_drag = false,
            .entered_and_exited = ptr.presence != null,
            .in_visible_rect = true,
            .mouse_moved = ptr.hover != null,
        };
        const tracking_area = cocoa.alloc("NSTrackingArea")
            .msgSend(objc.Object, "initWithRect:options:owner:userInfo:", .{
                cocoa.NSRect.make(0, 0, 0, 0),
                @as(u64, @bitCast(area_options)),
                self.value,
                cocoa.nil,
        });
        defer tracking_area.msgSend(void, "release", .{});
        self.msgSend(void, "addTrackingArea:", .{tracking_area});
    }
    
    return self.value;
}

fn acceptsFirstResponder(target: objc.c.id, sel: objc.c.SEL) callconv(.C) objc.c.BOOL {
    _ = sel;
    const self = objc.Object.fromId(target);
    const data = self.getInstanceVariable("data")
        .msgSend(?*anyopaque, "bytes", .{});
    const opts: *prism.Widget.Options = @ptrCast(@alignCast(data orelse return cocoa.YES));
    if (opts.click != null or opts.drag != null or opts.hover != null or opts.presence != null) return cocoa.YES;
    return cocoa.NO;
}

fn mouseMoved(target: objc.c.id, sel: objc.c.SEL, event_id: objc.c.id) callconv(.C) void {
    _ = sel;
    const self = objc.Object.fromId(target);
    const opts_ptr = self.getInstanceVariable("options")
        .msgSend(*anyopaque, "bytes", .{});
    const opts: *prism.Widget.Options = @ptrCast(@alignCast(opts_ptr));
    if (opts.hover) |hover| {
        const context = self.getInstanceVariable("context");
        const ptr = context.value orelse null;

        const event = objc.Object.fromId(event_id);
        const pt = event.getProperty(cocoa.NSPoint, "locationInWindow");
        const coord = self.msgSend(cocoa.NSPoint, "convertPoint:fromView:", .{
            pt,
            cocoa.nil,
        });
        if (hover(ptr, coord.x, coord.y)) {
            const next = self.getProperty(objc.Object, "nextResponder");
            next.msgSend(void, "mouseMoved:", .{event});
        }
    } else {
        const next = self.getProperty(objc.Object, "nextResponder");
        next.msgSend(void, "mouseMoved:", .{event_id});
    }
}

fn mousePresence(target: objc.c.id, sel: objc.c.SEL, event_id: objc.c.id) callconv(.C) void {
    const self = objc.Object.fromId(target);
    const opts_ptr = self.getInstanceVariable("options")
        .msgSend(*anyopaque, "bytes", .{});
    const opts: *prism.Widget.Options = @ptrCast(@alignCast(opts_ptr));
    const name = objc.Sel.getName(.{ .value = sel });
    if (opts.presence) |presence| {
        const context = self.getInstanceVariable("context");
        const ptr: ?*anyopaque = context.value orelse null;

        const is_enter = @import("std").mem.eql(u8, name, "mouseEntered:");

        if (presence(ptr, is_enter)) {
            const next = self.getProperty(objc.Object, "nextResponder");
            next.msgSend(void, name, .{event_id});
        }
    } else {
        const next = self.getProperty(objc.Object, "nextResponder");
        next.msgSend(void, name, .{event_id});
    }
}

fn mouseClicked(target: objc.c.id, sel: objc.c.SEL, event_id: objc.c.id) callconv(.C) void {
    const Sel: objc.Sel = .{
        .value = sel,
    };
    const self = objc.Object.fromId(target);
    const opts_ptr = self.getInstanceVariable("options")
        .msgSend(*anyopaque, "bytes", .{});
    const opts: *prism.Widget.Options = @ptrCast(@alignCast(opts_ptr));
    if (opts.click) |click| {
        const context = self.getInstanceVariable("context");
        const ptr: ?*anyopaque = context.value orelse null;

        const name = objc.Sel.getName(.{ .value = sel });
        const button: prism.MouseButton, const is_release = blk: {
            if (@import("std").mem.eql(u8, name, "mouseDown:"))
                break :blk .{ .left, false };
            if (@import("std").mem.eql(u8, name, "rightMouseDown:"))
                break :blk .{ .right, false };
            if (@import("std").mem.eql(u8, name, "otherMouseDown:"))
                break :blk .{ .other, false };
            if (@import("std").mem.eql(u8, name, "mouseUp:"))
                break :blk .{ .left, true };
            if (@import("std").mem.eql(u8, name, "rightMouseUp:"))
                break :blk .{ .right, true };
            if (@import("std").mem.eql(u8, name, "otherMouseUp:"))
                break :blk .{ .other, true };
            unreachable;
        };

        const event = objc.Object.fromId(event_id);
        const pt = event.getProperty(cocoa.NSPoint, "locationInWindow");
        const coord = self.msgSend(cocoa.NSPoint, "convertPoint:fromView:", .{
            pt,
            cocoa.nil,
        });

        if (click(ptr, coord.x, coord.y, button, is_release)) {
            const next = self.getProperty(objc.Object, "nextResponder");
            next.msgSend(void, Sel, .{event_id});
        }
    } else {
        const next = self.getProperty(objc.Object, "nextResponder");
        next.msgSend(void, Sel, .{event_id});
    }
}

fn mouseDragged(target: objc.c.id, sel: objc.c.SEL, event_id: objc.c.id) callconv(.C) void {
    const Sel: objc.Sel = .{ .value = sel };
    const self = objc.Object.fromId(target);
    const opts_ptr = self.getInstanceVariable("options")
        .msgSend(*anyopaque, "bytes", .{});
    const opts: *prism.Widget.Options = @ptrCast(@alignCast(opts_ptr));
    if (opts.drag) |drag| {
        const context = self.getInstanceVariable("context");
        const ptr: ?*anyopaque = context.value orelse null;

        const name = objc.Sel.getName(.{ .value = sel });
        const button: prism.MouseButton = blk: {
            if (@import("std").mem.eql(u8, name, "mouseDragged:"))
                break :blk .left;
            if (@import("std").mem.eql(u8, name, "rightMouseDragged:"))
                break :blk .right;
            if (@import("std").mem.eql(u8, name, "otherMouseDragged:"))
                break :blk .other;
            unreachable;
        };

        const event = objc.Object.fromId(event_id);
        const pt = event.getProperty(cocoa.NSPoint, "locationInWindow");
        const coord = self.msgSend(cocoa.NSPoint, "convertPoint:fromView:", .{
            pt,
            cocoa.nil,
        });

        if (drag(ptr, coord.x, coord.y, button)) {
            const next = self.getProperty(objc.Object, "nextResponder");
            next.msgSend(void, Sel, .{event_id});
        }
    } else {
        const next = self.getProperty(objc.Object, "nextResponder");
        next.msgSend(void, Sel, .{event_id});
    }
}
    
