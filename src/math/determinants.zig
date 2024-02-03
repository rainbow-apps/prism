/// interprets `rows` as an array of row vectors
pub fn determinant(comptime n: usize, comptime F: type, rows: [n][n]F, eps: F) F {
    if (F != f32 and F != f64) @compileError("unknown floating point type!");
    const V = @Vector(n, F);
    var matrix: [n]V = undefined;
    var det: F = 1;
    inline for (0..n) |i| {
        matrix[i] = rows[i];
    }
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const j = j: {
            for (i..n) |j| {
                if (@abs(matrix[j][i]) > eps) break :j j;
            } else return 0;
        };
        if (j != i) {
            const v: V = matrix[j];
            matrix[j] = matrix[i];
            matrix[i] = v;
            det = -det;
        }
        det *= matrix[i][i];
        matrix[i] /= @splat(matrix[i][i]);
        for (i + 1..n) |k| {
            const v: V = @splat(matrix[k][i]);
            matrix[k] -= v * matrix[i];
        }
    }
    return det;
}

test "determinants" {
    const testing = @import("std").testing;
    const eps: f32 = 0.0001;
    const A: [2][2]f32 = .{
        .{ 1, 1 },
        .{ 2, 2 },
    };
    try testing.expectApproxEqAbs(0, determinant(2, f32, A, eps), eps);
    const B: [3][3]f32 = .{
        .{ 1, 2, 3 },
        .{ 0, 1, 2 },
        .{ 0, 0, 1 },
    };
    try testing.expectApproxEqAbs(1, determinant(3, f32, B, eps), eps);
    const C: [2][2]f32 = .{
        .{ 0.00001, 0.5 },
        .{ 2, 1 },
    };
    try testing.expectApproxEqAbs(-1, determinant(2, f32, C, eps), eps);
}
