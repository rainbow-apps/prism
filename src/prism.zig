const builtin = @import("builtin");

const Cocoa = Prism(@import("backend/cocoa.zig"));
const Gtk = Prism(@import("backend/gtk.zig"));
const Win32 = Prism(@import("backend/win32.zig"));

pub usingnamespace switch (builtin.os.tag) {
    .linux => Gtk,
    .macos => Cocoa,
    .windows => Win32,
    else => {
        @compileLog(builtin.os);
        @compileError("no default backend for this target!");
    },
};

pub const GraphicsBackend = enum {
    Metal,
    OpenGL,
    D3D12,
    Vulkan,
    Native,
};

fn Prism(comptime T: type) type {
    return struct {

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
                },
                Horizontal: struct {
                    content_alignment: enum { left, right, center },
                    child_alignment: enum { top, bottom, center },
                    spacing: Amount,
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
                context: ?*anyopaque,
                width: Layout.Amount,
                height: Layout.Amount,
                draw: *const DrawFn,
                hover: ?*const HoverFn,
                presence: ?*const PresenceFn,
                click: ?*const ClickFn,
                drag: ?*const DragFn,
                other_teardown: ?*const OtherFn,
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

        const This = @This();
        pub fn Graphics(comptime backend: GraphicsBackend) type {
            const G = switch (backend) {
                .D3D12 => T.D3D12,
                .Metal => T.Metal,
                .Vulkan => T.Vulkan,
                .OpenGL => T.OpenGL,
                .Native => {
                    switch (builtin.os.tag) {
                        .macos => return This.Graphics(.Metal),
                        .linux => return This.Graphics(.Vulkan),
                        .windows => return This.Graphics(.D3D12),
                        else => {
                            @compileLog(builtin.os.tag);
                            @compileError("no default graphics backend for this target!");
                        },
                    }
                },
            };
            return struct {
                /// opaque pointer to backend-specific representation of GPU device.
                handle: *anyopaque,

                pub const Backend = backend;

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

                pub const PixelShader = struct {
                    /// opaque pointer to graphics-backend-specific representation of pixel shader
                    handle: *anyopaque,

                    pub const Err = error{CompilationFailed};

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
            };
        }

        pub const MouseButton = enum { left, right, other };

        test {
            @import("std").testing.refAllDeclsRecursive(@This());
        }
    };
}

test "run tests" {
    switch (builtin.os.tag) {
        .linux => {
            _ = Gtk.Graphics(.Native);
            _ = Gtk;
        },
        .macos => _ = {
            _ = Cocoa.Graphics(.Native);
            _ = Cocoa;
        },
        .windows => {
            _ = Win32.Graphics(.Native);
            _ = Win32;
        },
        else => {},
    }
}

test "basic button" {
    @import("std").testing.log_level = .info;
    const Inner = struct {
        fn action(_: ?*anyopaque) void {
            @import("std").log.info("clicked!", .{});
        }
    };

    const This = @This();
    try This.init();
    defer This.deinit();

    const window = try This.Window.create(.{
        .title = "prism-test",
        .size = .{
            .width = 500,
            .height = 500,
        },
        .exit_on_close = true,
    });
    defer window.destroy();
    window.setContent(try This.Layout.create(.{ .Horizontal = .{
        .content_alignment = .center,
        .child_alignment = .center,
        .spacing = .{ .fraction = 0.05 },
    } }, .{
        try This.NativeButton.widget(.{
            .text = "click me!",
            .action = Inner.action,
            .ctx = null,
        }),
        try This.NativeButton.widget(.{
            .text = "or me!",
            .action = Inner.action,
            .ctx = null,
        }),
    }));

    This.run();
    defer This.stop();
}
