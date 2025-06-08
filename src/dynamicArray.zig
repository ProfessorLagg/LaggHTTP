const builtin = @import("builtin");
const std = @import("std");

fn swapFn(comptime T: type) fn (*T, *T) void {
    const fns = struct {
        fn swap_xor(x: *T, y: *T) void {
            if (@intFromPtr(x) == @intFromPtr(y)) return;
            x.* = y.* ^ x.*;
            y.* = x.* ^ y.*;
            x.* = y.* ^ x.*;
        }
        // fn swap_xor_ptr(a: *T, b: *T) void {
        //     std.debug.assert(@typeInfo(T) == .pointer);
        //     if (@intFromPtr(a) == @intFromPtr(b)) return;
        //     const x: *usize = @ptrCast(a);
        //     const y: *usize = @ptrCast(b);
        //     x.* = y.* ^ x.*;
        //     y.* = x.* ^ y.*;
        //     x.* = y.* ^ x.*;
        // }
        fn swap_tmp(x: *T, y: *T) void {
            if (@intFromPtr(x) == @intFromPtr(y)) return;
            const temp: T = x.*;
            x.* = y.*;
            y.* = temp;
        }
    };

    const ti: std.builtin.Type = comptime @typeInfo(T);
    return comptime switch (ti) {
        .int => fns.swap_xor,
        .pointer => fns.swap_xor,
        // TODO swap_xor by bitcasting floats
        else => fns.swap_tmp,
    };
}

pub fn DynamicArray(comptime T: type) type {
    if (@sizeOf(T) == 0) unreachable;
    return struct {
        const Self = @This();

        const swap = swapFn(T);

        allocator: std.mem.Allocator,
        /// Pointer to the backing buffer.
        buf_ptr: [*]T,
        /// Size of the backing buffer.
        capacity: usize,
        /// Number of items in the array
        count: usize,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .buf_ptr = undefined,
                .capacity = 0,
                .count = 0,
            };
        }

        pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !Self {
            var r = Self{
                .allocator = allocator,
                .buf_ptr = undefined,
                .capacity = 0,
                .count = 0,
            };
            try r.ensureCapacity(capacity);
            return r;
        }

        inline fn free_buffer(self: *Self) void {
            const buffer = self.buf_ptr[0..self.capacity];
            self.allocator.free(buffer);
            self.capacity = 0;
        }
        pub fn deinit(self: *Self) void {
            self.free_buffer();
        }

        /// Ensures that `self.capacity` is atleast `capacity`.
        /// Returns `true` if pointers where invalidated due to resize
        pub fn ensureCapacity(self: *Self, capacity: usize) !bool {
            if (capacity <= self.capacity or capacity == 0) return false;

            const log2_capacity = std.math.log2_int(usize, capacity);
            const new_capacity: usize = try std.math.powi(usize, 2, log2_capacity + 1);
            std.debug.assert(std.math.isPowerOfTwo(new_capacity));
            std.debug.assert(new_capacity > self.capacity);
            std.debug.assert(new_capacity >= capacity);

            const buf_old: []T = self.buf_ptr[0..self.capacity];
            const resize_succes = self.allocator.resize(buf_old, new_capacity);
            if (resize_succes) return false;

            const new_buf: []T = self.allocator.remap(buf_old, new_capacity) orelse blk: {
                var r: []T = try self.allocator.alloc(T, new_capacity);
                @memcpy(r[0..buf_old.len], buf_old);
                self.allocator.free(buf_old);
                break :blk r;
            };
            const pointers_invalid = self.buf_ptr != new_buf.ptr;
            self.buf_ptr = new_buf.ptr;
            self.capacity = new_buf.len;
            return pointers_invalid;
        }

        pub inline fn items(self: *Self) []T {
            return self.buf_ptr[0..self.count];
        }
        pub inline fn constItems(self: *const Self) []const T {
            return self.buf_ptr[0..self.count];
        }

        /// Appends the item to the end of the array
        /// Returns `true` if pointers where invalidated due to resize
        pub fn append(self: *Self, item: T) !bool {
            const r = try self.ensureCapacity(self.count + 1);
            self.buf_ptr[self.count] = item;
            self.count += 1;
            return r;
        }

        /// Removes the last item from the array and returns it
        /// If the array contains no items, returns `null`
        pub fn removeLast(self: *Self) ?T {
            if (self.count == 0) {
                @branchHint(.unlikely);
                return null;
            }

            self.count -= 1;
            return self.buf_ptr[self.count];
        }

        /// Removes the item at `index` by swapping it with the last item in the array.
        /// - Does not preserve ordering
        /// - If `index` >= `self.count` returns null
        pub fn removeSwap(self: *Self, index: usize) ?T {
            if (index >= self.count) return null;
            if (index == self.count - 1) return self.removeLast();

            self.count -= 1;
            swap(T, &self.buf_ptr[index], &self.buf_ptr[self.count]);
            return self.buf_ptr[self.count];
        }

        /// Removes the item at `index` by shifting it into the last position
        /// - Preserves ordering
        /// - If `index` >= `self.count` returns null
        pub fn removeByShift(self: *Self, index: usize) ?T {
            if (index >= self.count) return null;
            if (index == self.count - 1) return self.removeLast();

            const buf: []T = self.buf_ptr[index..self.count];
            std.mem.rotate(T, buf, 1);
            self.count -= 1;
            return self.buf_ptr[self.count];
        }
    };
}
