const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.SSO);

pub const SmallString = struct {
    const largeSize: usize = @sizeOf(usize) + @sizeOf(*u8);
    const Tlen_bitcount: u16 = @intCast(std.math.log2_int_ceil(usize, largeSize));
    const Tlen: type = std.meta.Int(.unsigned, Tlen_bitcount);
    pub const bufsize: usize = largeSize - @sizeOf(Tlen);

    buf: [bufsize]u8 align(8) = undefined,
    len: Tlen = 0,
};
pub const LargeString = []u8;
pub const SSO_TYPE = enum(u1) {
    small,
    large,
};
pub const SSO = union(SSO_TYPE) {
    small: SmallString,
    large: LargeString,

    pub fn isSmallLen(len: usize) bool {
        return len <= SmallString.bufsize;
    }

    pub fn initAlloc(allocator: std.mem.Allocator, str: []const u8) !SSO {
        var result: SSO = undefined;
        log.debug("New SSO: \"{s}\"", .{str});
        if (SSO.isSmallLen(str.len)) {
            std.debug.assert(str[0..].len <= SmallString.bufsize);
            result = SSO{ .small = SmallString{} };
            result.small.len = @truncate(str.len);
            std.mem.copyForwards(u8, result.small.buf[0..str.len], str[0..]);
            return result;
        } else {
            std.debug.assert(str[0..].len > SmallString.bufsize);
            result = SSO{ .large = try allocator.alloc(u8, str.len) };
            std.mem.copyForwards(u8, result.large[0..], str[0..]);
            return result;
        }
    }
    pub fn initRef(str: []const u8) SSO {
        var result: SSO = undefined;
        if (SSO.isSmallLen(str.len)) {
            std.debug.assert(str[0..].len <= SmallString.bufsize);
            result = SSO{ .small = SmallString{} };
            result.small.len = @truncate(str.len);
            std.mem.copyForwards(u8, result.small.buf[0..str.len], str[0..]);
            return result;
        } else {
            std.debug.assert(str[0..].len > SmallString.bufsize);
            result = SSO{ .large = @constCast(str) };
            return result;
        }
    }

    pub fn clone(self: *const SSO, allocator: std.mem.Allocator) !SSO {
        const deref = self.*;
        return switch (deref) {
            .small => deref,
            .large => try SSO.initAlloc(allocator, self.large),
        };
    }

    pub fn deinit(self: SSO, allocator: std.mem.Allocator) void {
        const tag: SSO_TYPE = @as(SSO_TYPE, self);
        switch (tag) {
            .small => {},
            .large => {
                log.debug("Freeing SSO: \"{s}\"", .{self.large});
                allocator.free(self.large);
            },
        }
    }

    pub fn toString(self: *const SSO) []const u8 {
        const tag = @as(SSO_TYPE, self.*);
        return switch (tag) {
            .small => self.small.buf[0..self.small.len],
            .large => self.large,
        };
    }

    fn compareNumber(comptime T: type, a: T, b: T) i8 {
        const lt: i8 = @intFromBool(a < b) * @as(i8, -1); // -1 if true, 0 if false
        const gt: i8 = @intFromBool(a > b); // 1 if true, 0 if false
        return lt + gt;
    }

    /// Used for sorting. Compares SSO's to figure out sort order.
    /// Returns -1 if a < b, 0 if a == b and 1 if a > b
    pub fn compare(a: SSO, b: SSO) i8 {
        const A: []const u8 = a.toString();
        const B: []const u8 = b.toString();
        var cmp: i8 = compareNumber(usize, A.len, B.len);
        var i: usize = 0;
        while (cmp != 0 and i < A.len) : (i += 1) cmp = compareNumber(u8, A[i], B[i]);
        return cmp;
    }
};

/// Sorted Map where both keys and values are SSO's
pub const SSOMap = struct {
    allocator: std.mem.Allocator,
    key_buffer: []SSO,
    val_buffer: []SSO,
    count: usize,

    pub fn init(allocator: std.mem.Allocator) !SSOMap {
        return SSOMap{
            .allocator = allocator,
            .key_buffer = try allocator.alloc(SSO, 2),
            .val_buffer = try allocator.alloc(SSO, 2),
            .count = 0,
        };
    }

    pub fn deinit(self: *SSOMap) void {
        for (self.keys(), self.values()) |k, v| {
            k.deinit(self.allocator);
            v.deinit(self.allocator);
        }
        self.allocator.free(self.key_buffer);
        self.allocator.free(self.val_buffer);
    }

    pub fn keys(self: *const SSOMap) []const SSO {
        var r = self.key_buffer[0..];
        r.len = self.count;
        return r;
    }
    pub fn values(self: *const SSOMap) []const SSO {
        return self.val_buffer[0..self.count];
    }

    pub fn indexOf(self: *const SSOMap, key: SSO) ?usize {
        const k: SSO = SSO.initRef(key);
        var L: isize = 0;
        var R: isize = @bitCast(self.count);
        var i: isize = undefined;
        var u: usize = undefined;
        var cmp: i8 = undefined;
        R -= 1;
        while (L <= R) {
            i = @divFloor(L + R, 2);
            u = @as(usize, @intCast(i));
            cmp = SSO.compare(self.key_buffer[u], k);
            switch (cmp) {
                -1 => L = i + 1,
                1 => R = i - 1,
                0 => return i,
            }
        }
        return -1;
    }

    /// Adds or overwrites value depending on if key already exists in the map
    pub fn put(self: *SSOMap, key: []const u8, value: []const u8) !void {
        const k: SSO = SSO.initRef(key);
        const v: SSO = SSO.initRef(value);
        const I: InsertIndex = self.getInsertIndex(k);
        if (I.cmp == 0) {
            self.val_buffer[I.idx] = v;
        }

        switch (I.cmp) {
            -1 => try self.insertAt(
                try k.clone(self.allocator),
                try v.clone(self.allocator),
                I.idx,
            ),

            0 => {
                self.val_buffer[I.idx].deinit(self.allocator);
                self.val_buffer[I.idx] = try v.clone(self.allocator);
            },

            1 => try self.insertAt(
                try k.clone(self.allocator),
                try v.clone(self.allocator),
                I.idx + 1,
            ),

            else => unreachable,
        }
    }

    pub fn remove(self: *SSOMap, key: []const u8) !void {
        const k: SSO = SSO.initRef(key);
        const i: usize = self.indexOf(k) orelse return void;
        try self.removeAt(i);
    }

    const InsertIndex = packed struct {
        /// Index to insert at
        idx: std.meta.Int(.unsigned, @bitSizeOf(usize) - @sizeOf(i8)),
        /// result of SSO.compare(key, key_buffer[idx])
        cmp: i8,
    };
    fn getInsertIndex(self: *SSOMap, key: SSO) InsertIndex {
        var result: InsertIndex = .{ .idx = 0, .cmp = -1 };
        if (self.count == 0) return result;

        result.cmp = SSO.compare(key, self.key_buffer[0]);
        if (self.count == 1) return result;

        // TODO Actually use binary search here
        while (result.cmp == 1) {
            result.idx += 1;
            if (result.idx == self.count) break;
            std.debug.assert(result.idx < self.count);
            result.cmp = SSO.compare(key, self.key_buffer[result.idx]);
        }
        return result;
    }

    pub fn getCapacity(self: *SSOMap) usize {
        std.debug.assert(self.key_buffer.len == self.val_buffer.len);
        return self.key_buffer.len;
    }

    /// Grows key/value buffers to fit capacity if needed
    fn ensureCapacity(self: *SSOMap, capacity: usize) !void {
        const old_capacity = self.getCapacity();
        if (old_capacity >= capacity) return;

        const new_capacity = @max(1, old_capacity * 2); // We never go below 1 capacity here
        std.debug.assert(new_capacity > old_capacity);
        const new_key_buffer = try self.allocator.alloc(SSO, new_capacity);
        const new_val_buffer = try self.allocator.alloc(SSO, new_capacity);
        @memcpy(new_key_buffer[0..old_capacity], self.key_buffer[0..]);
        @memcpy(new_val_buffer[0..old_capacity], self.val_buffer[0..]);
        self.allocator.free(self.key_buffer);
        self.allocator.free(self.val_buffer);
        self.key_buffer = new_key_buffer;
        self.val_buffer = new_key_buffer;
    }

    /// Shrinks capacity to lowest power of 2 greater than count
    pub fn shrinkToFit(self: *SSOMap) !void {
        const old_capacity = self.getCapacity();
        const new_capacity = std.math.ceilPowerOfTwo(usize, self.count);
        if (new_capacity < old_capacity) {
            const new_key_buffer = try self.allocator.alloc(SSO, new_capacity);
            const new_val_buffer = try self.allocator.alloc(SSO, new_capacity);
            @memcpy(new_key_buffer[0..], self.key_buffer[0..new_capacity]);
            @memcpy(new_val_buffer[0..], self.val_buffer[0..new_capacity]);
            self.allocator.free(self.key_buffer);
            self.allocator.free(self.val_buffer);
            self.key_buffer = new_key_buffer;
            self.val_buffer = new_key_buffer;
        }
    }

    /// Inserts a new key/value pair into the map.
    /// Increases self.count, and grows capacity if needed
    fn insertAt(self: *SSOMap, k: SSO, v: SSO, index: usize) !void {
        try self.ensureCapacity(self.count + 1);
        if (index == self.count) {
            self.key_buffer[index] = k;
            self.val_buffer[index] = v;
            self.count += 1;
            return;
        }

        // Shift the key/value pairs down by 1 starting at index
        var ci = self.count;
        while (ci > index) : (ci -= 1) {
            self.key_buffer[ci] = self.key_buffer[ci - 1];
            self.val_buffer[ci] = self.val_buffer[ci - 1];
        }
        self.count += 1;
        self.key_buffer[index] = k;
        self.val_buffer[index] = v;
    }
    fn removeAt(self: *SSOMap, index: usize) !void {
        std.debug.assert(index < self.count);
        if (index == self.count - 1) {
            // remove last element
            self.key_buffer[index].deinit(self.allocator);
            self.val_buffer[index].deinit(self.allocator);
            self.count -= 1;
        } else {
            self.key_buffer[index].deinit(self.allocator);
            self.val_buffer[index].deinit(self.allocator);
            self.count -= 1;
            // Shift the key/value pairs up by 1 starting at index
            var ci = index;
            while (ci < self.count) : (ci += 1) {
                self.key_buffer[ci] = self.key_buffer[ci + 1];
                self.val_buffer[ci] = self.val_buffer[ci + 1];
            }
        }
    }
};
