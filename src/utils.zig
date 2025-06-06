const builtin = @import("builtin");
const std = @import("std");

pub const math = struct {
    pub fn log10_int_ceil(comptime T: type, num: T) T {
        comptime {
            const Ti = @typeInfo(T);
            const errmsg = "Expected integer type, but found " ++ @typeName(T);
            if (Ti != .int) @compileError(errmsg);
        }
        const log10_floor: T = std.math.log10_int(num);
        const pow10: T = powi_panic(T, 10, log10_floor);
        const addOne: bool = pow10 == num;
        return log10_floor + @intFromBool(addOne);
    }

    pub inline fn powi_panic(comptime T: type, x: T, y: T) T {
        return std.math.powi(T, x, y) catch |err| @panic(err);
    }

    fn divCeil_uint(comptime T: type, x: T, y: T) T {
        comptime meta.assertUnsignedInteger(T);
        const floor: T = @divFloor(x, y);
        const add: T = @intFromBool((floor * y) == x);
        return floor + add;
    }
    fn divCeil_sint(comptime T: type, x: T, y: T) T {
        comptime meta.assertSignedInteger(T);
        const floor: T = @divFloor(x, y);
        const add: T = @intFromBool((floor * y) == x);
        return floor + add;
    }
    fn divCiel_float(comptime T: type, x: T, y: T) T {
        comptime meta.assertFloat(T);
        return @ceil(x / y);
    }

    fn divCiel_vecf(comptime T: type, x: T, y: T) T {
        comptime meta.assertFloatVector(T);
        return @ceil(x / y);
    }
    /// calculates x / y, rounding to the nearest whole number towards positive infinity
    pub fn divCeil(comptime T: type, x: T, y: T) T {
        const divFn = comptime blk: {
            if (meta.isUnsignedInteger(T)) break :blk divCeil_uint;
            if (meta.isSignedInteger(T)) break :blk divCeil_sint;
            if (meta.isFloat(T)) break :blk divCiel_float;
            if (meta.isTypedVector(T, meta.isFloat)) break :blk divCiel_vecf;
            if (meta.isTypedVector(T, meta.isUnsignedInteger)) @compileError("Not yet implemented"); // TODO
            if (meta.isTypedVector(T, meta.isSignedInteger)) @compileError("Not yet implemented"); // TODO
            unreachable;
        };
        return @call(.always_inline, divFn, .{ T, x, y });
    }
};

pub const strings = struct {
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
    pub fn streql(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (0..a.len) |i| if (a[i] != b[i]) return false;
        return true;
    }

    /// Converts base 10 utf-8 string to a signed integer
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
    /// Converts base 10 utf-8 string to an unsigned integer
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
    /// Converts integer to base 10 utf-8 string
    pub fn fastIntToString(comptime T: type, num: T, buffer: []u8) []const u8 {
        const Ti = comptime @typeInfo(T);
        comptime {
            const errmsg = "Expected integer type, but found " ++ @typeName(T);
            if (Ti != .int) {
                @compileLog(errmsg);
                unreachable;
            }
        }
        var n = @abs(num);
        if (n == 0) {
            buffer[0] = '0';
            return buffer[0..1];
        }
        var i: usize = buffer.len;
        while (n > 0) {
            i -= 1;
            buffer[i] = @intCast((n % 10) + 48);
            n = n / 10;
        }
        const negativeInt: u8 = @intFromBool(num < 0);
        const positiveInt: u8 = @intFromBool(num >= 0);
        i -= negativeInt;
        buffer[i] = ('-' * negativeInt) + (buffer[i] * positiveInt);

        return buffer[i..];
    }

    test fastIntToString {
        var buf_e: [16]u8 = undefined;
        var buf_f: [16]u8 = undefined;
        var i: isize = 99;
        while (i > -99) : (i -= 1) {
            const expect = try std.fmt.bufPrint(&buf_e, "{d}", .{i});
            const found = fastIntToString(@TypeOf(i), i, &buf_f);
            std.testing.expectEqualStrings(expect, found) catch |err| {
                std.log.err("\n\te:\"{s}\"\n\tf:\"{s}\"", .{ expect, found });
                return err;
            };
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

    pub fn c_string_to_slice(c_string: [*]const u8) []const u8 {
        var r: []const u8 = undefined;
        r.ptr = c_string;
        r.len = 0;
        while (c_string[r.len] != 0) : (r.len += 1) {}
        return r;
    }

    pub fn compareFromBools(lt: bool, gt: bool) i2 {
        if (lt and gt) { // both cannot be true
            @branchHint(.cold);
            unreachable;
        }
        const lti: i2 = @as(i2, -1) * @as(i2, @intFromBool(lt));
        const gti: i2 = @intFromBool(lt);
        return lti + gti;
    }
    pub fn compareNumberAsc(comptime T: type) fn (a: T, b: T) i2 {
        meta.assertNumber(T);
        return struct {
            fn f(a: T, b: T) i2 {
                return compareFromBools(a < b, a > b);
            }
        }.f;
    }
    pub fn compareNumberDsc(comptime T: type) fn (a: T, b: T) i2 {
        meta.assertNumber(T);
        return struct {
            fn f(a: T, b: T) i2 {
                return compareFromBools(a > b, a < b);
            }
        }.f;
    }

    /// Finds the index of an item in the array using binary search.
    /// Returns null if the item is not found
    pub fn binarySearch(
        comptime T: type,
        /// comparison function. Must return the following:
        /// - a < b return -1
        /// - a = b return  0
        /// - a > b return +1
        comptime compareFn: fn (a: T, b: T) i2,
        arr: []const T,
        item: T,
    ) ?usize {
        if (arr.len == 0) {
            @branchHint(.unlikely);
            return null;
        }

        var L: isize = 0;
        var R: isize = @as(isize, @intCast(arr.len)) - 1;
        var mi: isize = undefined;
        var mu: usize = undefined;
        var cmp: i2 = undefined;
        var gt: isize = undefined;
        var le: isize = undefined;
        while (L != R) {
            mi = L + math.divCeil(isize, (R - L), 2);
            mu = @abs(mi);
            cmp = compareFn(arr[mu], item);
            gt = @intFromBool(cmp == 1);
            le = @intFromBool(cmp != 1);
            R = (R * le) + ((mi - 1) * gt);
            L = (mi * le) + (L * gt);
        }
        if (cmp == 0) return mu;
        return null;
    }
};

pub const meta = struct {
    pub fn printSize(comptime T: type) void {
        const stdout = std.io.getStdOut().writer();
        std.fmt.format(stdout, "size of {s} = {d}\n", .{ @typeName(T), @sizeOf(T) }) catch return;
    }
    pub fn printEnumTags(comptime T: type) void {
        const Ti: std.builtin.Type = comptime @typeInfo(T);
        comptime if (Ti != .@"enum") @compileError("Expected enum type, but found: " ++ @typeName(T));

        const stdout = std.io.getStdOut().writer();
        std.fmt.format(stdout, "fields in enum {s}:\n", .{@typeName(T)}) catch {};
        inline for (Ti.@"enum".fields) |field| {
            std.fmt.format(stdout, "\t{s} = {any}\n", .{ field.name, field.value }) catch {};
        }
    }
    pub fn printErrorSet(comptime T: type) void {
        const Ti: std.builtin.Type = comptime @typeInfo(T);
        comptime if (Ti != .error_set) @compileError("Expected error_set type, but found: " ++ @typeName(T));

        const stdout = std.io.getStdOut().writer();
        std.fmt.format(stdout, "fields in error set:\n", .{}) catch {};
        if (Ti.error_set == null) return;
        const fields: []const std.builtin.Type.Error = Ti.error_set.?;
        inline for (fields) |field| {
            std.fmt.format(stdout, "\t{s}\n", .{field.name}) catch {};
        }
    }

    pub fn EnumErrorSet(comptime T: type) type {
        comptime {
            const enum_Ti: std.builtin.Type = @typeInfo(T);
            if (enum_Ti != .@"enum") @compileError("Expected enum type, but found: " ++ @typeName(T));
            const enum_fields = enum_Ti.@"enum".fields;
            var err_fields: [enum_fields.len]std.builtin.Type.Error = undefined;
            for (0..enum_fields.len) |i| {
                err_fields[i] = std.builtin.Type.Error{ .name = enum_fields[i].name };
            }
            return @Type(std.builtin.Type{ .error_set = err_fields[0..] });
        }
    }
    fn EnumErrorMapVal(comptime T: type) type {
        return struct {
            @"enum": T,
            @"error": anyerror,
        };
    }
    fn get_enum_err_mapping(comptime T: type, comptime Ti: std.builtin.Type.Enum) [Ti.fields.len]EnumErrorMapVal(T) {
        comptime {
            @setEvalBranchQuota(1024 * 1024 * 1024);
            var arr: [Ti.fields.len]EnumErrorMapVal(T) = undefined;
            for (0..Ti.fields.len) |i| {
                arr[i] = .{
                    .@"enum" = @field(T, Ti.fields[i].name),
                    .@"error" = @field(EnumErrorSet(T), Ti.fields[i].name),
                };
            }
            return arr;
        }
    }
    pub inline fn EnumValueToError(comptime T: type, enum_value: T) anyerror {
        const Ti: std.builtin.Type = comptime @typeInfo(T);
        comptime if (Ti != .@"enum") @compileError("Expected enum type, but found: " ++ @typeName(T));
        const enum_err_mapping = comptime get_enum_err_mapping(T, Ti.@"enum");

        for (enum_err_mapping[0..]) |mapping| {
            const en = mapping.@"enum";
            const er = mapping.@"error";
            if (enum_value == en) return er;
        }
        unreachable;
    }

    // Type Checks
    pub fn isNumber(comptime T: type) bool {
        comptime {
            return isInteger(T) or isFloat(T);
        }
    }
    pub fn assertNumber(comptime T: type) void {
        comptime if (!isNumber(T)) unreachable;
    }

    pub fn isInteger(comptime T: type) bool {
        comptime {
            const ti: std.builtin.Type = @typeInfo(T);
            return ti == .int;
        }
    }
    pub fn assertInteger(comptime T: type) void {
        comptime if (!isInteger(T)) unreachable;
    }

    pub fn isSignedInteger(comptime T: type) bool {
        comptime {
            const ti: std.builtin.Type = @typeInfo(T);
            return ti == .int and ti.int.signedness == .signed;
        }
    }
    pub fn assertSignedInteger(comptime T: type) void {
        comptime if (!isSignedInteger(T)) unreachable;
    }

    pub fn isUnsignedInteger(comptime T: type) bool {
        comptime {
            const ti: std.builtin.Type = @typeInfo(T);
            return ti == .int and ti.int.signedness == .unsigned;
        }
    }
    pub fn assertUnsignedInteger(comptime T: type) void {
        comptime if (!isUnsignedInteger(T)) unreachable;
    }

    pub fn isFloat(comptime T: type) bool {
        comptime {
            const ti: std.builtin.Type = @typeInfo(T);
            return ti == .float;
        }
    }
    pub fn assertFloat(comptime T: type) void {
        comptime if (!isFloat(T)) unreachable;
    }

    pub fn isVector(comptime T: type) bool {
        comptime {
            const ti: std.builtin.Type = @typeInfo(T);
            return ti == .vector;
        }
    }
    pub fn assertVector(comptime T: type) bool {
        comptime if (!isVector(T)) unreachable;
    }

    pub fn isTypedVector(
        comptime T: type,
        /// function that returns `true` if vector child type is valid, otherwise `false`
        comptime typecheck: fn (comptime type) bool,
    ) bool {
        comptime {
            const ti: std.builtin.Type = @typeInfo(T);
            return ti == .vector and typecheck(ti.vector.child);
        }
    }
    pub fn assertTypedVector(
        comptime T: type,
        /// function that returns `true` if vector child type is valid, otherwise `false`
        comptime typecheck: fn (comptime type) bool,
    ) bool {
        comptime if (!isTypedVector(T, typecheck)) unreachable;
    }
};

pub const UtilError = error{
    NotYetImplemented,
};

pub fn PackedSlice(comptime T: type) type {
    return packed struct {
        len: usize,
        ptr: [*]T,
    };
}

pub fn noop() void {}
pub fn noop_err() anyerror!void {}

test math {
    _ = math;
}
test strings {
    _ = strings;
}
