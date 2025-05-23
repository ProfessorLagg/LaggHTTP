const std = @import("std");

pub fn Offset(comptime Tidx: type, comptime Tlen: type) type {
    comptime {
        const Tidx_info: std.builtin.Type = @typeInfo(Tidx);
        if (Tidx_info != .int) @compileError("Expected unsigned integer, but found: " ++ @typeName(Tidx));
        if (Tidx_info.int.signedness != .unsigned) @compileError("Expected unsigned integer, but found: " ++ @typeName(Tidx));

        const Tlen_info: std.builtin.Type = @typeInfo(Tidx);
        if (Tlen_info != .int) @compileError("Expected unsigned integer, but found: " ++ @typeName(Tlen));
        if (Tlen_info.int.signedness != .unsigned) @compileError("Expected unsigned integer, but found: " ++ @typeName(Tlen));
    }

    return packed struct {
        const TSelf = @This();
        index: Tidx,
        length: Tlen,

        pub fn slice(comptime T: type, self: TSelf, arr: []const T) []const T {
            std.debug.assert(self.index < arr.len);
            std.debug.assert((self.index + self.length) <= arr.len);
            return arr[self.index..self.length];
        }
    };
}

/// Calculates the minimum size unsigned integer that can fit max_val
pub fn MinUInt(comptime max_value: comptime_int) type {
    comptime {
        if (max_value <= 0) @compileError("max_value must be positive and greater than 0");
        const bits: u16 = @intCast(std.math.log2_int_ceil(comptime_int, max_value));
        return std.meta.Int(.unsigned, bits);
    }
}
