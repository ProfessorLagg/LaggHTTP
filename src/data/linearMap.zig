const builtin = @import("builtin");
const std = @import("std");

pub fn EqualFn(comptime T: type) type {
    return (fn (T, T) bool);
}
pub fn LinearMap(comptime TKey: type, comptime TVal: type, comptime equals: EqualFn(TKey)) type {
    return struct {
        const TSelf = @This();

        allocator: std.mem.Allocator,
        keybuf: []TKey,
        valbuf: []TVal,

        keys: []TKey,
        vals: []TVal,

        pub fn init(allocator: std.mem.Allocator) !TSelf {
            var r = TSelf{
                .allocator = allocator,
                .keybuf = try allocator.alloc(TKey, 2),
                .valbuf = try allocator.alloc(TVal, 2),
            };

            r.keys = r.keybuf[0..0];
            r.val = r.valbuf[0..0];
        }

        pub fn deinit(self: *TSelf) void {
            self.allocator.free(self.keybuf);
            self.allocator.free(self.valbuf);
        }

        fn resize(self: *TSelf, new_len: usize) !void {
            _ = &new_len;
            _ = &self;
        }

        fn grow(self: *TSelf) !void {
            _ = &self;
        }

        fn shrink(self: *TSelf) !void {
            _ = &self;
        }

        pub fn put(self: *TSelf, key: TKey, val: TVal) !void {
            if (self.keys.len == self.keybuf.len) self.grow();

            _ = &key;
            _ = &val;
        }
    };
}
