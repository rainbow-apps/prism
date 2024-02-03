const builtin = @import("builtin");
const options = @import("options");

const T = switch (options.backend) {
    .cocoa => @import("backend/cocoa.zig"),
    .gtk => @import("backend/gtk.zig"),
    .win32 => @import("backend/win32.zig"),
    .none => @compileError("backend must be explicitly provided with -Dbackend for this target!"),
};

const G = switch (options.graphics) {
    .metal => T.Metal,
    .openGL => T.OpenGL,
    .d3d12 => T.D3D12,
    .vulkan => T.Vulkan,
    .none => @compileError("graphics backend must be explicitly provided with -Dgraphics for this target!"),
};

// core setup

/// sets up the prism backend.
/// must be called before other prism code runs.
/// must be called on the main thread.
pub const init = T.init;

/// stops the prism backend.
pub const deinit = T.deinit;

pub const run = T.run;
pub const stop = T.stop;

// setup error
pub const AppError = error{
    PlatformCodeFailed,
};

// core types
pub const Window = struct {
    /// opaque pointer to backend-specific representation of the window
    handle: *anyopaque,

    pub const Options = struct {
        /// null makes the window untitled
        title: ?[:0]const u8 = "",
        closable: bool = true,
        miniaturizable: bool = true,
        resizable: bool = true,
        exit_on_close: bool = false,
        size: struct {
            width: f64,
            height: f64,
        },
        position: struct {
            x: f64,
            y: f64,
        } = .{ .x = 100, .y = 100 },
    };

    /// creates a window
    pub const create = T.Window.create;
    /// destroys a window
    pub const destroy = T.Window.destroy;
    /// sets the window's content
    pub const setContent = T.Window.setContent;
};
// pub const Loop = T.Loop;
pub const Layout = struct {
    /// opaque pointer to backend-specific representation of the layout
    handle: *anyopaque,

    pub const Error = error{BadConstraints} || AppError;

    /// creates a layout object with specified options and children
    pub const create = T.Layout.create;
    pub const destroy = T.Layout.destroy;

    pub const Options = union(Kind) {
        Box: struct {
            margins: struct {
                left: Amount,
                right: Amount,
                top: Amount,
                bottom: Amount,
            },
        },
        Vertical: struct {
            content_alignment: enum { top, bottom, center },
            child_alignment: enum { left, right, center },
            spacing: Amount,
            container_size: Amount,
        },
        Horizontal: struct {
            content_alignment: enum { left, right, center },
            child_alignment: enum { top, bottom, center },
            spacing: Amount,
            container_size: Amount,
        },

        const Kind = enum {
            Box,
            Vertical,
            Horizontal,
        };
    };
    /// for specifying sizes in either absolute (pixels) or relative (fraction) terms
    pub const Amount = union(enum) {
        pixels: f64,
        fraction: f64,
    };
};
pub const Widget = struct {
    /// opaque pointer to backend-specific representation of the widget
    handle: *anyopaque,

    pub const destroy = T.Widget.destroy;

    pub const Options = struct {
        user_ctx: ?*anyopaque,
        width: Layout.Amount,
        height: Layout.Amount,
        hover: ?*const HoverFn,
        presence: ?*const PresenceFn,
        click: ?*const ClickFn,
        drag: ?*const DragFn,
    };

    pub const DrawFn = fn (self: *anyopaque) void;
    pub const HoverFn = fn (ctx: ?*anyopaque, x: f64, y: f64) bool;
    pub const PresenceFn = fn (ctx: ?*anyopaque, is_enter: bool) bool;
    pub const ClickFn = fn (ctx: ?*anyopaque, x: f64, y: f64, button: MouseButton, is_release: bool) bool;
    pub const DragFn = fn (ctx: ?*anyopaque, x: f64, y: f64, button: MouseButton) bool;
    pub const OtherFn = fn (self: *anyopaque) void;
    // key
};

pub const NativeButton = struct {
    pub const widget = T.NativeButton.widget;

    // pub const update = T.NativeButton.update;

    pub const Options = struct {
        text: [:0]const u8,
        /// called on mouse down
        action: *const fn (ctx: ?*anyopaque) void,
        ctx: ?*anyopaque,
    };
};

pub const Graphics = struct {
    /// opaque pointer to backend-specific representation of GPU device.
    handle: *anyopaque,

    pub const Backend = options.graphics;

    pub const Err = error{CompilationFailed};

    /// call before using any methods in this struct.
    /// should be called on the main thread
    pub const init = G.init;

    pub const RenderingContext = struct {
        /// opaque pointer to backend-specific representation of rendering context
        handle: *anyopaque,

        /// creates a rendering context
        pub const create = G.create;
        /// destroys a rendering context
        pub const destroy = G.destroy;
    };

    pub const PrismButton = struct {
        /// creates a Widget
        pub const widget = G.PrismButton.widget;

        pub const Options = struct {
            text: struct {
                string: [:0]const u8,
                font_name: [:0]const u8,
                font_size: u16,
            },
            horizontal_pad: Layout.Amount,
            vertical_pad: Layout.Amount,
            border_thickness: f32,
            bg: Color,
            fg: Color,
            hl_bg: Color,
            hl_fg: Color,
            clickFn: *const fn (?*anyopaque) void,
            user_data: ?*anyopaque,
        };
    };

    pub const Color = struct {
        r: f32,
        g: f32,
        b: f32,
        a: f32 = 1,
    };

    pub const Point = struct {
        x: f32,
        y: f32,
    };

    pub const PixelShader = struct {
        /// opaque pointer to graphics-backend-specific representation of pixel shader
        handle: *anyopaque,

        pub const Options = struct {
            size: struct {
                width: Layout.Amount,
                height: Layout.Amount,
            },
        };

        /// defines a pixel shader
        pub const define = G.PixelShader.define;
        /// destroys a pixel shader's GPU representation
        pub const dispose = G.PixelShader.dispose;
        /// creates a Widget from a pixel shader object
        pub const widget = G.PixelShader.widget;
        /// updates user data for given widget
        /// the passed widget must have been created from a PixelShader
        /// by calling `widget`.
        pub const updateWidgetUserData = G.PixelShader.updateWidgetUserData;

        test {
            @import("std").testing.refAllDeclsRecursive(@This());
        }
    };

    pub const Drawing = struct {
        pub const widget = G.Drawing.widget;

        pub const redisplay = G.Drawing.redisplay;
        pub const point = G.Drawing.point;
        pub const points = G.Drawing.points;
        pub const rect = G.Drawing.rect;
        pub const rects = G.Drawing.rects;
        pub const rect_fill = G.Drawing.rect_fill;
        pub const rects_fill = G.Drawing.rects_fill;
        pub const quad = G.Drawing.quad;
        pub const tri = G.Drawing.tri;
        pub const line = G.Drawing.line;
        pub const lines = G.Drawing.lines;
        pub const mesh = G.Drawing.mesh;

        pub const PointData = struct {
            color: Color,
            point: Point,
            size: f32,
        };

        pub const RectLineData = struct {
            color: Color,
            origin: Point,
            opposite: Point,
            thickness: f32,
        };

        pub const RectFillData = struct {
            color: Color,
            origin: Point,
            opposite: Point,
        };

        pub const VertexData = struct {
            color: Color,
            point: Point,
        };
    };

    test {
        @import("std").testing.refAllDeclsRecursive(@This());
    }
};

pub const MouseButton = enum { left, right, other };

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}

test "run tests" {
    _ = Graphics;
}

test "drawing" {
    const eps = 0.00001;
    const inner = struct {
        fn draw(wid: Widget) !void {
            const std = @import("std");
            var r = std.rand.DefaultPrng.init(@intCast(@max(std.time.nanoTimestamp(), 0)));
            var pts: [25][2]f32 = undefined;
            var col: [25]Graphics.Color = undefined;
            const random = r.random();
            while (true) {
                std.time.sleep(std.time.ns_per_s / 2);
                inline for (0..25) |i| {
                    pts[i] = .{
                        100 + 500 * random.float(f32),
                        100 + 400 * random.float(f32),
                    };
                    col[i] = .{
                        .r = random.float(f32),
                        .g = random.float(f32),
                        .b = random.float(f32),
                        .a = 0.5,
                    };
                }
                const del = @import("math/delaunay.zig");
                const triangulation = del.delaunay(
                    std.testing.allocator,
                    &pts,
                    eps,
                ) catch |err| switch (err) {
                    error.BadMesh => continue,
                    else => return err,
                };
                defer std.testing.allocator.free(triangulation);
                const mesh = try std.testing.allocator.alloc(Graphics.Drawing.VertexData, triangulation.len * 3);
                defer std.testing.allocator.free(mesh);
                for (triangulation, 0..) |tri, i| {
                    inline for (mesh[i * 3 ..][0..3], tri) |*v, t| {
                        v.color = color: {
                            for (0..25) |j| {
                                if (t[0] == pts[j][0] and t[1] == pts[j][1])
                                    break :color col[j];
                            }
                            unreachable;
                        };
                        v.point = .{
                            .x = t[0],
                            .y = t[1],
                        };
                    }
                }
                Graphics.Drawing.mesh(wid, mesh);
                Graphics.Drawing.redisplay(wid);
            }
        }
    };

    try init();
    defer deinit();

    const graphics = try Graphics.init();
    const ctx = try Graphics.RenderingContext.create(graphics);
    defer ctx.destroy();

    const window = try Window.create(.{
        .title = "prism-drawing-test",
        .size = .{
            .width = 700,
            .height = 600,
        },
        .exit_on_close = true,
    });
    defer window.destroy();

    const wid = try Graphics.Drawing.widget(ctx, .{
        .user_ctx = null,
        .width = .{ .fraction = 1.0 },
        .height = .{ .fraction = 1.0 },
        .hover = null,
        .presence = null,
        .click = null,
        .drag = null,
    });

    window.setContent(wid);

    const pid = try @import("std").Thread.spawn(.{}, inner.draw, .{wid});
    pid.detach();

    run();
    defer stop();
}

test "prism_button" {
    @import("std").testing.log_level = .info;
    const inner = struct {
        fn clickFn(_: ?*anyopaque) void {
            @import("std").log.info("clicked!", .{});
        }
    };

    try init();
    defer deinit();

    const graphics = try Graphics.init();
    const context = try Graphics.RenderingContext.create(graphics);
    defer context.destroy();

    const window = try Window.create(.{
        .title = "prism-button-test",
        .size = .{
            .width = 500,
            .height = 400,
        },
        .exit_on_close = true,
    });
    defer window.destroy();

    const bg: Graphics.Color = .{ .r = 0.3, .g = 0.2, .b = 0.4, .a = 1.0 };
    const fg: Graphics.Color = .{ .r = 0.6, .g = 0.4, .b = 0.2, .a = 1.0 };
    const hl_fg: Graphics.Color = .{ .r = 0.6, .g = 0.4, .b = 0.8, .a = 1.0 };
    const hl_bg: Graphics.Color = .{ .r = 0.3, .g = 0.2, .b = 0.2, .a = 1.0 };

    window.setContent(try Layout.create(.{ .Box = .{
        .margins = .{
            .top = .{ .pixels = 30 },
            .bottom = .{ .pixels = 5 },
            .left = .{ .pixels = 5 },
            .right = .{ .pixels = 5 },
        },
    } }, .{
        try Graphics.PrismButton.widget(context, .{
            .border_thickness = 4,
            .horizontal_pad = .{ .fraction = 0.8 },
            .vertical_pad = .{ .fraction = 0.4 },
            .text = .{
                .string = "text",
                .font_name = "Helvetica",
                .font_size = 180,
            },
            .clickFn = inner.clickFn,
            .user_data = null,
            .bg = bg,
            .fg = fg,
            .hl_fg = hl_fg,
            .hl_bg = hl_bg,
        }),
    }));

    run();
    defer stop();
}

test "basic button" {
    @import("std").testing.log_level = .info;
    const Inner = struct {
        fn action(_: ?*anyopaque) void {
            @import("std").log.info("clicked!", .{});
        }
    };

    try init();
    defer deinit();

    const window = try Window.create(.{
        .title = "prism-test",
        .size = .{
            .width = 500,
            .height = 500,
        },
        .exit_on_close = true,
    });
    defer window.destroy();
    window.setContent(
        try Layout.create(.{ .Horizontal = .{
            .content_alignment = .center,
            .child_alignment = .center,
            .spacing = .{ .pixels = 0 },
            .container_size = .{ .fraction = 1 },
        } }, .{
            try Layout.create(.{ .Horizontal = .{
                .content_alignment = .center,
                .child_alignment = .center,
                .spacing = .{ .pixels = 0.05 },
                .container_size = .{ .fraction = 0.6 },
            } }, .{
                try Layout.create(.{ .Box = .{
                    .margins = .{
                        .top = .{ .pixels = 30 },
                        .bottom = .{ .pixels = 5 },
                        .left = .{ .pixels = 5 },
                        .right = .{ .pixels = 5 },
                    },
                } }, .{
                    try NativeButton.widget(.{
                        .text = "click me!",
                        .action = Inner.action,
                        .ctx = null,
                    }),
                }),
                try Layout.create(.{ .Box = .{
                    .margins = .{
                        .top = .{ .pixels = 30 },
                        .bottom = .{ .pixels = 5 },
                        .left = .{ .pixels = 5 },
                        .right = .{ .pixels = 5 },
                    },
                } }, .{
                    try NativeButton.widget(.{
                        .text = "or me!",
                        .action = Inner.action,
                        .ctx = null,
                    }),
                }),
            }),
            try Layout.create(.{ .Horizontal = .{
                .container_size = .{ .fraction = 0.4 },
                .content_alignment = .center,
                .child_alignment = .center,
                .spacing = .{ .pixels = 0.05 },
            } }, .{
                try Layout.create(.{ .Box = .{
                    .margins = .{
                        .top = .{ .pixels = 30 },
                        .bottom = .{ .pixels = 5 },
                        .left = .{ .pixels = 0 },
                        .right = .{ .pixels = 5 },
                    },
                } }, .{
                    try NativeButton.widget(.{
                        .text = "i am a button with longer text :)",
                        .action = Inner.action,
                        .ctx = null,
                    }),
                }),
            }),
        }),
    );

    run();
    defer stop();
}
