const builtin = @import("builtin");
const std = @import("std");

const memutils = @import("utils.zig").mem;

pub fn LinearMap(comptime TKey: type, comptime TVal: type, comptime equals: memutils.EqualFn(TKey)) type {
    return struct {
        const TSelf = @This();
        const min_capacity: usize = 2;
        const max_capactiy: usize = std.math.maxInt(usize);
        const KVP = struct { key: TKey, val: TKey };

        allocator: std.mem.Allocator,

        keybuf: []TKey,
        valbuf: []TVal,

        keys: []TKey,
        vals: []TVal,

        pub fn init(allocator: std.mem.Allocator) !TSelf {
            var r = TSelf{
                .allocator = allocator,
                .keybuf = try allocator.alloc(TKey, min_capacity),
                .valbuf = try allocator.alloc(TVal, min_capacity),
            };

            r.keys = r.keybuf[0..0];
            r.val = r.valbuf[0..0];
        }

        pub fn deinit(self: *TSelf) void {
            self.allocator.free(self.keybuf);
            self.allocator.free(self.valbuf);
        }

        fn grow(self: *TSelf) !void {
            const new_capacity = std.math.clamp(self.keybuf.len * 2, min_capacity, min_capacity);
            memutils.resize(TKey, &self.keybuf, new_capacity);
            memutils.resize(TKey, &self.valbuf, new_capacity);
            self.keys = self.keybuf[0..self.keys.len];
            self.vals = self.keybuf[0..self.vals.len];
        }

        fn shrink(self: *TSelf) !void {
            const new_capacity = std.math.clamp(self.keybuf.len / 2, min_capacity, min_capacity);
            memutils.resize(TKey, &self.keybuf, new_capacity);
            memutils.resize(TKey, &self.valbuf, new_capacity);
            self.keys = self.keybuf[0..self.keys.len];
            self.vals = self.keybuf[0..self.vals.len];
        }

        inline fn growIfNeeded(self: *TSelf) !bool {
            if (self.keys.len == self.keybuf.len) {
                try self.grow();
                return true;
            }
            return false;
        }
        inline fn shrinkIfNeeded(self: *TSelf) !void {
            if (self.keys.len <= @divFloor(self.keybuf.len, 2)) {
                try self.grow();
                return true;
            }
            return false;
        }

        pub fn put(self: *TSelf, key: TKey, val: TVal) !void {
            try @call(.always_inline, putR, .{ self, &key, &val });
        }
        pub fn putR(self: *TSelf, key: *const TKey, val: *const TVal) !void {
            for (0..self.keys.len) |i| {
                if (equals(key, &self.keys[i])) {
                    self.vals[i] = val.*;
                    return;
                }
            }

            try self.growIfNeeded();
            self.keybuf[self.keys.len] = key.*;
            self.valbuf[self.keys.len] = val.*;
            self.keys.len += 1;
            self.vals.len += 1;
        }

        pub fn removeShift(self: *TSelf, key: TKey) !?TVal {
            return try @call(.always_inline, removeShiftR, .{ self, &key });
        }
        pub fn removeShiftR(self: *TSelf, key: *const TKey) !?TVal {
            for (0..self.keys.len) |i| {
                if (equals(key, &self.keys[i])) {
                    memutils.rotateLeft(TKey, self.keys[i..]);
                    memutils.rotateLeft(TKey, self.vals[i..]);
                    self.keys.len -= 1;
                    self.vals.len -= 1;
                    try self.shrinkIfNeeded();
                    return self.valbuf[self.vals.len];
                }
            }

            return null;
        }
    };
}
