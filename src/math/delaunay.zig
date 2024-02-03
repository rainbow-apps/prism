const circularOrder = @import("circular.zig").circularOrder;
const determinant = @import("determinants.zig").determinant;
const std = @import("std");

pub const Err = std.mem.Allocator.Error || error{BadMesh};

pub fn delaunay(allocator: std.mem.Allocator, verts: []const [2]f32, eps: f32) Err![][3][2]f32 {
    const V = @Vector(2, f32);
    var triangles = std.ArrayList([3][2]f32).init(allocator);
    defer triangles.deinit();
    var bad_triangles = std.ArrayList([3][2]f32).init(allocator);
    defer bad_triangles.deinit();
    var edges = std.ArrayList([2]V).init(allocator);
    defer edges.deinit();

    const big_tri = bigTriangle(verts);
    try triangles.append(big_tri);
    for (verts) |v| {
        {
            const slice = try triangles.toOwnedSlice();
            defer allocator.free(slice);
            for (slice) |tri| {
                if (insideCircumcircle(tri, v, eps))
                    try bad_triangles.append(tri)
                else
                    try triangles.append(tri);
            }
        }
        defer edges.clearRetainingCapacity();
        {
            defer bad_triangles.clearRetainingCapacity();

            for (bad_triangles.items, 0..) |tri, i| {
                const e: []const [2]V = &.{
                    .{ tri[0], tri[1] },
                    .{ tri[1], tri[2] },
                    .{ tri[2], tri[0] },
                };
                for (e) |edge| {
                    var found = false;
                    for (bad_triangles.items[i + 1 ..]) |other_tri| {
                        const f: []const [2]V = &.{
                            .{ other_tri[0], other_tri[1] },
                            .{ other_tri[1], other_tri[2] },
                            .{ other_tri[2], other_tri[0] },
                        };
                        for (f) |other_edge| {
                            if (sameEdge(edge, other_edge)) {
                                found = true;
                                break;
                            }
                        }
                        if (found) break;
                    } else {
                        try edges.append(edge);
                    }
                }
            }
        }
        for (edges.items) |e| {
            switch (circularOrder(f32, e[0], e[1], v, eps)) {
                .ccw => try triangles.append(.{ e[0], e[1], v }),
                .cw => try triangles.append(.{ e[0], v, e[1] }),
                .cl => return error.BadMesh,
            }
        }
    }
    const slice = try triangles.toOwnedSlice();
    defer allocator.free(slice);
    for (slice) |tri| {
        var found = false;
        inline for (tri) |v| {
            inline for (big_tri) |w| {
                if (@reduce(.And, @as(V, v) == @as(V, w))) found = true;
            }
        }
        // if (!found) {
        // for (triangles.items) |other| {
        // if (found) continue;
        // for (tri) |v| {
        // for (other) |w| {
        // if (@reduce(.And, @as(V, v) == @as(V, w))) break;
        // } else continue;
        // break;
        // } else found = true;
        // }
        // }
        if (!found)
            try triangles.append(tri);
    }
    return try triangles.toOwnedSlice();
}

fn bigTriangle(verts: []const [2]f32) [3][2]f32 {
    const min, const max = minmax: {
        var min: f32 = 0;
        var max: f32 = 0;
        for (verts) |v| {
            min = @min(min, @min(v[0], v[1]));
            max = @max(max, @max(v[0], v[1]));
        }
        break :minmax .{ min, max };
    };
    const len = 2 * (max - min + 1);
    return .{
        .{ min - 1, min - 1 },
        .{ min + len, min - 1 },
        .{ min - 1, min + len },
    };
}

fn insideCircumcircle(tri: [3][2]f32, v: [2]f32, eps: f32) bool {
    const matrix: [4][4]f32 = .{
        .{ tri[0][0], tri[0][1], tri[0][0] * tri[0][0] + tri[0][1] * tri[0][1], 1 },
        .{ tri[1][0], tri[1][1], tri[1][0] * tri[1][0] + tri[1][1] * tri[1][1], 1 },
        .{ tri[2][0], tri[2][1], tri[2][0] * tri[2][0] + tri[2][1] * tri[2][1], 1 },
        .{ v[0], v[1], v[0] * v[0] + v[1] * v[1], 1 },
    };
    return determinant(4, f32, matrix, eps) > eps;
}

fn sameEdge(e: [2][2]f32, f: [2][2]f32) bool {
    const V = @Vector(2, f32);
    const v: V = e[0];
    const w: V = e[1];
    const x: V = f[0];
    const y: V = f[1];
    return (@reduce(.And, v == x) and
        @reduce(.And, w == y)) or
        (@reduce(.And, v == y) and
        @reduce(.And, w == x));
}

test "bigTriangle" {
    const testing = std.testing;
    const verts: []const [2]f32 = &.{
        .{ 0, 0 },
        .{ 1, 0 },
        .{ 1, 1 },
        .{ 0, 2 },
    };
    const big_tri = bigTriangle(verts);
    try testing.expectEqual(.ccw, circularOrder(f32, big_tri[0], big_tri[1], big_tri[2], 0.0001));
}

test "circumCircle" {
    const testing = std.testing;
    const verts: []const [2]f32 = &.{
        .{ 0, 0 },
        .{ 1, 0 },
        .{ 1, 1 },
        .{ 0, 2 },
    };
    const tri = bigTriangle(verts);
    for (verts) |v| {
        try testing.expect(insideCircumcircle(tri, v, 0.0001));
    }
}

test "sameEdge" {
    const testing = std.testing;
    const verts: []const [2]f32 = &.{
        .{ 0, 0 },
        .{ 1, 0 },
        .{ 0, 1 },
    };
    const edges: []const [2][2]f32 = &.{
        .{ verts[0], verts[1] },
        .{ verts[1], verts[0] },
        .{ verts[0], verts[2] },
    };
    try testing.expect(sameEdge(edges[0], edges[0]));
    try testing.expect(sameEdge(edges[0], edges[1]));
    try testing.expect(!sameEdge(edges[0], edges[2]));
}

test "delaunay" {
    const testing = std.testing;
    testing.log_level = .info;
    const verts: []const [2]f32 = &.{
        .{ 0, 0 },
        .{ 1, 0 },
        .{ 0, 1 },
        .{ 2, 1 },
    };
    const triangulation: []const [3][2]f32 = &.{ .{
        .{ 0, 0 },
        .{ 1, 0 },
        .{ 0, 1 },
    }, .{
        .{ 0, 1 },
        .{ 1, 0 },
        .{ 2, 1 },
    } };
    const del = try delaunay(testing.allocator, verts, 0.0001);
    defer testing.allocator.free(del);
    try testing.expectEqualSlices([3][2]f32, triangulation, del);
}
