const none = "graphics features not available! compile prism with -Dgraphics=... to enable!";

pub const init = @compileError(none);
pub const deinit = @compileError(none);
