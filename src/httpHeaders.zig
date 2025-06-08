const builtin = @import("builtin");
const std = @import("std");
const utils = @import("utils.zig");
const DynamicArray = @import("dynamicArray.zig").DynamicArray;

pub const HttpHeader = struct {
    buf_ptr: [*]const u8,
    buf_len: u16,
    keylen: u8,

    inline fn isWhitespaceUtf8(char: u8) bool {
        // https://stackoverflow.com/a/46637343
        const whitespace_chars: @Vector(8, u8) = comptime [_]u8{
            0x09, //character tabulation
            0x0A, //line feed
            0x0B, //line tabulation
            0x0C, //form feed
            0x0D, //carriage return
            0x20, //space
            0x85, //next line
            0xA0, //no-break space
        };

        const eqlvec = whitespace_chars == @as(@TypeOf(whitespace_chars), @splat(char));
        return @reduce(.Or, eqlvec);
    }
    fn trimKey(key: []const u8) []const u8 {
        var left: usize = 0;
        var right: usize = key.len - 1;
        while (isWhitespaceUtf8(key[left]) and left < right) : (left += 1) {}
        while ((isWhitespaceUtf8(key[right]) or key[right] == ':') and right > left) : (right -= 1) {}
        return key[left .. right + 1];
    }
    fn trimVal(val: []const u8) []const u8 {
        var left: usize = 0;
        var right: usize = val.len - 1;
        while ((isWhitespaceUtf8(val[left]) or val[left] == ':') and left < right) : (left += 1) {}
        while (isWhitespaceUtf8(val[right]) and right > left) : (right -= 1) {}
        return val[left .. right + 1];
    }

    pub fn initAlloc(allocator: std.mem.Allocator, key: []const u8, val: []const u8) !HttpHeader {
        const k: []const u8 = trimKey(key);
        const v: []const u8 = trimVal(val);
        std.debug.assert(k.len <= std.math.maxInt(u8));
        std.debug.assert(v.len <= (std.math.maxInt(u16) - std.math.maxInt(u8)));
        std.debug.assert((k.len + v.len) <= std.math.maxInt(u16));

        var r: HttpHeader = .{
            .buf_ptr = undefined,
            .buf_len = @truncate(k.len + v.len + ": ".len),
            .keylen = @truncate(k.len),
        };
        const buf: []u8 = try allocator.alloc(u8, r.buf_len);
        _ = std.fmt.bufPrint(buf, "{s}: {s}", .{ k, v }) catch unreachable;
        r.buf_ptr = buf.ptr;

        return r;
    }
    pub fn deinit(self: *HttpHeader, allocator: std.mem.Allocator) void {
        allocator.free(self.string());
    }

    pub inline fn string(self: *const HttpHeader) []const u8 {
        return self.buf_ptr[0..self.buf_len];
    }
    pub inline fn keystr(self: *const HttpHeader) []const u8 {
        return self.buf_ptr[0..self.keylen];
    }
    pub inline fn valstr(self: *const HttpHeader) []const u8 {
        const left = self.keylen + ": ".len;
        return self.buf_ptr[left..self.buf_len];
    }

    pub fn eql(self: *const HttpHeader, other: *const HttpHeader) bool {
        return std.mem.eql(u8, self.keystr(), other.keystr());
    }
    pub fn keyeql(self: *const HttpHeader, key: []const u8) bool {
        return std.mem.eql(u8, self.keystr(), key);
    }
};

pub const HttpHeaderMap = struct {
    allocator: std.mem.Allocator,
    kvps: DynamicArray(HttpHeader),

    pub fn init(allocator: std.mem.Allocator) HttpHeaderMap {
        return HttpHeaderMap{ .allocator = allocator, .kvps = DynamicArray(HttpHeader).init(allocator) };
    }
    pub fn deinit(self: *HttpHeaderMap) void {
        for (self.kvps.items()) |item| {
            const item_ptr: *HttpHeader = @constCast(&item);
            HttpHeader.deinit(item_ptr, self.allocator);
        }
        self.kvps.deinit();
    }

    pub inline fn all(self: *const HttpHeaderMap) []const HttpHeader {
        return self.kvps.constItems();
    }
    pub fn get(self: *const HttpHeaderMap, key: []const u8) ?HttpHeader {
        if (self.indexOf(key)) |idx| {
            return self.kvps.buf_ptr[idx];
        }
    }
    pub fn set(self: *HttpHeaderMap, key: []const u8, val: []const u8) !void {
        const new_header: HttpHeader = try HttpHeader.initAlloc(self.allocator, key, val);
        if (self.indexOf(key)) |idx| {
            const old_header: *HttpHeader = &self.kvps.buf_ptr[idx];
            old_header.deinit(self.allocator);
            self.kvps.buf_ptr[idx] = new_header;
        } else {
            _ = try self.kvps.append(new_header);
        }
    }
    pub fn remove(self: *const HttpHeader, key: []const u8) ?HttpHeader {
        if (self.indexOf(key)) |idx| {
            return self.headers.buf[idx];
        }
        return null;
    }

    fn indexOf(self: *const HttpHeaderMap, key: []const u8) ?usize {
        const items = self.kvps.constItems();
        for (0..items.len) |i| if (items[i].keyeql(key)) return i;
        return null;
    }
};
