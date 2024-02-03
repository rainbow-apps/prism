/// given three points, determines whether they are ordered counterclockwise
/// if in general position or colinear
pub fn circularOrder(comptime F: type, a: [2]F, b: [2]F, c: [2]F, eps: F) Order {
    if (F != f32 and F != f64) @compileError("unknown floating point type!");
    const V = @Vector(2, F);
    const s: V = @as(V, b) - @as(V, a);
    const t: V = @as(V, c) - @as(V, b);

    // b and a are on a (roughly) vertical line
    if (@abs(s[0]) <= eps) {
        // so are c and b, so they're colinear
        if (@abs(t[0]) <= eps) return .cl;
        // b ~ a
        if (@abs(s[1]) <= eps) return .cl;
        // b is above a
        if (s[1] > eps) {
            // anything to the right of us is clockwise
            return if (t[0] > eps) .cw else .ccw;
        }
        // b is below a
        // anything to the right of us is counterclockwise
        return if (t[0] > eps) .ccw else .cw;
    }
    // c and b are on a (roughly) vertical line
    if (@abs(t[0]) <= eps) {
        // c ~ b
        if (@abs(t[1]) <= eps) return .cl;
        // c is above b
        if (t[1] > eps) {
            // anything to the left of us is counterclockwise
            return if (s[0] > eps) .ccw else .cw;
        }
        // c is below b
        // anything to the left of us is clockwise
        return if (s[0] > eps) .cw else .ccw;
    }
    const sl = s[1] / s[0];
    const tl = t[1] / t[0];
    // approximately colinear
    if (@abs(tl - sl) <= eps) return .cl;
    // s is in the right half-plane
    if (s[0] > eps) {
        // t is in the right half-plane
        if (t[0] > eps) {
            // increasing slope means counterclockwise
            return if (tl > sl) .ccw else .cw;
        }
        // t is in the left half-plane
        //  decreasing slope means counterclockwise
        return if (tl < sl) .ccw else .cw;
    }
    // s is in the left half-plane
    // t is in the right half-plane
    if (t[0] > eps) {
        // decreasing slope means counterclockwise
        return if (tl < sl) .ccw else .cw;
    }
    // t is in the left half-plane
    // increasing slope means counterclockwise
    return if (tl > sl) .ccw else .cw;
}

pub const Order = enum { ccw, cw, cl };

test "circularOrder" {
    const testing = @import("std").testing;
    const pts: []const [2]f32 = &.{
        .{ 0, 0 },
        .{ 1, 0 },
        .{ 1, 1 },
        .{ 0, 1 },
        .{ -1, 0 },
    };
    const eps: f32 = 0.001;
    try testing.expectEqual(.ccw, circularOrder(f32, pts[0], pts[1], pts[2], eps));
    try testing.expectEqual(.cw, circularOrder(f32, pts[3], pts[2], pts[1], eps));
    try testing.expectEqual(.cl, circularOrder(f32, pts[0], pts[1], pts[4], eps));
    try testing.expectEqual(.cl, circularOrder(f32, pts[0], pts[0], pts[4], eps));
}
