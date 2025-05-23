const builtin = @import("builtin");
const std = @import("std");

pub const Strings = struct {
    pub fn indexOf(str: []const u8, find: []const u8) ?usize {
        std.debug.assert(find.len <= str.len);
        for (0..str.len) |i| {
            const slice: []const u8 = str[i..(i + find.len)];
            if (std.mem.eql(u8, slice, find)) return i;
        }
        return null;
    }

    pub fn fastIntParse(comptime T: type, numstr: []const u8) T {
        // TODO assert T is integer

        std.debug.assert(numstr.len > 0);
        const isNegative: bool = numstr[0] == '-';
        const isNegativeInt: T = @intFromBool(isNegative);

        var result: T = 0;
        var m: T = 1;

        var i: isize = @as(isize, @intCast(numstr.len)) - 1;
        while (i >= isNegativeInt) : (i -= 1) {
            const ci: T = @intCast(numstr[@as(usize, @bitCast(i))]);
            const valid: bool = ci >= 48 and ci <= 57;
            const validInt: T = @intFromBool(valid);
            const invalidInt: T = @intFromBool(!valid);
            result += validInt * ((ci - 48) * m); // '0' = 48
            m = (m * 10 * validInt) + (m * invalidInt);
        }

        const sign: T = (-1 * isNegativeInt) + @as(T, @intFromBool(!isNegative));
        return result * sign;
    }
};

pub const ASCII = struct {
    /// Returns true if char is a number character: '0','1','2','3','4','5','6','7','8','9'
    pub fn isNumberChar(char: u8) bool {
        return char >= '0' and char <= '9';
    }
};
