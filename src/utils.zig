const builtin = @import("builtin");
const std = @import("std");

pub const Strings = struct {
    pub fn indexOf(str: []const u8, find: []const u8) ?usize {
        if (find.len > str.len) {
            @branchHint(.unlikely);
            return null;
        }
        var slice: []const u8 = str[0..find.len];
        for (0..str.len) |i| {
            if (std.mem.eql(u8, slice, find)) return i;
            slice.ptr += 1;
        }
        return null;
    }

    pub fn fastIntParse(comptime T: type, numstr: []const u8) T {
        comptime {
            const Ti = @typeInfo(T);
            const errmsg = "Expected signed integer type, but found " ++ @typeName(T);
            if (Ti != .int) @compileError(errmsg);
            if (Ti.int.signedness != .signed) @compileError(errmsg);
        }

        std.debug.assert(numstr.len > 0);
        const isNegative: bool = numstr[0] == '-';
        const isNegativeInt: T = @intFromBool(isNegative);

        var result: T = 0;
        var m: T = 1;

        var i: isize = @as(isize, @intCast(numstr.len)) - 1;
        while (i >= isNegativeInt) : (i -= 1) {
            const charT: T = @intCast(numstr[@as(usize, @bitCast(i))]);
            const valid: bool = charT >= 48 and charT <= 57;
            const validInt: T = @intFromBool(valid);
            const invalidInt: T = @intFromBool(!valid);
            result += validInt * ((charT - 48) * m); // '0' = 48
            m = (m * 10 * validInt) + (m * invalidInt);
        }

        const sign: T = (-1 * isNegativeInt) + @as(T, @intFromBool(!isNegative));
        return result * sign;
    }

    pub fn fastUIntParse(comptime T: type, numstr: []const u8) T {
        comptime {
            const Ti = @typeInfo(T);
            const errmsg = "Expected unsigned integer type, but found " ++ @typeName(T);
            if (Ti != .int) @compileError(errmsg);
            if (Ti.int.signedness != .unsigned) @compileError(errmsg);
        }

        std.debug.assert(numstr.len > 0);
        var result: T = 0;
        var m: T = 1;

        var i: usize = numstr.len - 1;
        while (true) {
            const char: T = numstr[i];
            const valid: bool = char >= 48 and char <= 57;
            const validInt: T = @intFromBool(valid);
            const invalidInt: T = @intFromBool(!valid);
            result += (validInt * ((char - 48) * m)); // '0' = 48;

            if (i == 0) return result;
            m = (m * 10 * validInt) + (m * invalidInt);
            i -= 1;
        }
    }
};

pub const ASCII = struct {
    /// Returns true if char is a number character: '0','1','2','3','4','5','6','7','8','9'
    pub fn isNumberChar(char: u8) bool {
        return char >= '0' and char <= '9';
    }
};

pub const mem = struct {
    pub fn clone(comptime T: type, allocator: std.mem.Allocator, arr: []const T) ![]T {
        const result: []T = try allocator.alloc(T, arr.len);
        @memcpy(result, arr);
        return result;
    }

    pub fn ensureResize(comptime T: type, allocator: std.mem.Allocator, arr_ptr: *[]T, new_len: usize) std.mem.Allocator.Error!void {
        if (new_len == arr_ptr.len) {
            @branchHint(.cold);
            return;
        }
        const arr: []T = arr_ptr.*;
        if (allocator.resize(arr, new_len)) {
            arr_ptr.* = arr[0..new_len];
        } else {
            const new_arr: []T = try allocator.alloc(T, new_len);
            @memcpy(new_arr[0..arr.len], arr);
            allocator.free(arr);
            arr_ptr.* = new_arr[0..];
        }
    }
};

pub fn noop() void {}
pub fn noop_err() anyerror!void{}