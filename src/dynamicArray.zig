const std = @import("std");

const memutils = @import("utils.zig").mem;

pub fn DynamicArray(comptime T: type) type {
    const min_capacity = comptime memutils.calculate_default_capacity(T);
    return struct {
        const TSelf = @This();
        allocator: std.mem.Allocator,
        buffer: []T,
        items: []T,

        pub fn init(allocator: std.mem.Allocator) !TSelf {
            var r = TSelf{
                .allocator = allocator,
                .buffer = undefined,
                .items = undefined,
            };

            r.buffer = try r.allocator.alloc(T, min_capacity);
            r.items = r.buffer[0..];
            r.items.len = 0;
        }

        pub fn deinit(self: *TSelf) void {
            self.allocator.free(self.buffer);
        }

        /// Resizes capacity the specified capacity.
        fn resize(self: *TSelf, new_capacity: usize) !void {
            std.debug.assert(self.items.len <= new_capacity);

            const old_len: usize = self.buffer.len;
            const new_len: usize = @max(new_capacity, min_capacity);
            const min_len: usize = @min(old_len, new_len);

            // TODO test out allocator.resize
            var new_buffer: []T = try self.allocator.alloc(T, new_len);
            @memcpy(new_buffer[0..min_len], self.buffer[0..min_len]);
            self.allocator.free(self.buffer);
            self.buffer = new_buffer;
            self.items = self.buffer[0..self.items.len];
        }
        /// Increases capacity by a power of 2
        fn grow(self: *TSelf) !void {
            const new_capacity: usize = @max(2, self.buffer.len * 2);
            try self.resize(new_capacity);
        }
        /// Reduces capacity by a power of 2
        fn shrink(self: *TSelf) !void {
            const new_capacity: usize = @max(2, self.buffer.len / 2);
            try self.resize(new_capacity);
        }
        /// calls shrink if needed and possible
        fn shrinkIfNeeded(self: *TSelf) !void {
            const new_capacity: usize = @max(2, self.buffer.len / 2);
            if (self.items.len < new_capacity) try self.resize(new_capacity);
        }

        /// Appends the item to the end of the array
        pub fn append(self: *TSelf, item: T) !void {
            if (self.items.len == self.buffer.len) self.grow();

            self.buffer[self.items.len] = item;
            self.items.len += 1;
        }
        /// Atempts to append the item to the end of the array. Returns true if successfull
        pub fn tryAppend(self: *TSelf, item: T) bool {
            self.append(item) catch return false;
            return true;
        }
        /// Appends the item at ptr to the end of the array
        pub fn appendR(self: *TSelf, ptr: *const T) !void {
            if (self.items.len == self.buffer.len) self.grow();

            self.buffer[self.items.len] = ptr.*;
            self.items.len += 1;
        }
        /// Atempts to append the item at ptr to the end of the array. Returns true if successfull
        pub fn tryAppendR(self: *TSelf, ptr: *const T) bool {
            self.appendR(ptr) catch return false;
            return true;
        }

        /// Inserts the item at the specified index
        pub fn insertAt(self: *TSelf, item: T, index: usize) !void {
            std.debug.assert(index <= self.items.len);

            if (index == self.items.len) {
                try self.append(item);
                return;
            }

            self.items.len += 1;
            memutils.shiftRight(T, self.items, index);
            self.items[index] = item;
        }
        /// Atempts to insert the item at the specified index. Returns true if successfull
        pub fn tryInsertAt(self: *TSelf, item: T, index: usize) bool {
            if (index > self.items.len) return false;
            self.insertAt(item, index) catch return false;
            return true;
        }
        /// Inserts the item at ptr at the specified index
        pub fn insertAtR(self: *TSelf, ptr: *const T, index: usize) !void {
            std.debug.assert(index <= self.items.len);

            if (index == self.items.len) {
                try self.appendR(ptr);
                return;
            }

            self.items.len += 1;
            memutils.shiftRight(T, self.items, index);
            self.items[index] = ptr.*;
        }
        /// Atempts to insert the item at the specified index. Returns true if successfull
        pub fn tryInsertAtR(self: *TSelf, ptr: *const T, index: usize) bool {
            if (index > self.items.len) return false;
            self.insertAtR(ptr, index) catch return false;
            return true;
        }

        /// Swaps the items at index x and y
        pub fn swap(self: *TSelf, x: usize, y: usize) void {
            std.debug.assert(x < self.items.len);
            std.debug.assert(y < self.items.len);
            if (x == y) return;

            // TODO do non cloning swap where it's possible
            const copy_x: T = self.items[x];
            self.items[x] = self.items[y];
            self.items[y] = copy_x;
        }

        /// Removes the item at the specified index by swapping it to the end of the array. Does not preserve ordering
        pub fn removeSwap(self: *TSelf, index: usize) !void {
            std.debug.assert(index < self.items.len);
            self.swap(index, self.items.len - 1);
            self.items.len -= 1;

            try self.shrinkIfNeeded();
        }
        /// Attemps to remove the item at the specified index by swapping it to the end of the array. Does not preserve ordering
        pub fn tryRemoveSwap(self: *TSelf, index: usize) bool {
            if (index < self.items.len) return false;
            self.removeSwap(index) catch return false;
            return true;
        }
        /// Removes the item at the specified index by shifting the array. Preserves ordering
        pub fn removeShift(self: *TSelf, index: usize) !void {
            std.debug.assert(index < self.items.len);
            memutils.rotateLeft(T, self.items[index..]);
            self.items.len -= 1;

            try self.shrinkIfNeeded();
        }
        /// Attemps to remove the item at the specified index by shifting the array. Preserves ordering
        pub fn tryRemoveShift(self: *TSelf, index: usize) bool {
            if (index < self.items.len) return false;
            self.removeShift(index) catch return false;
            return true;
        }

        /// Pops the last item off the array
        pub fn pop(self: *TSelf) ?T {
            if (self.items.len == 0) return null;
            self.items.len -= 1;
            return self.buffer[self.items.len];
        }
    };
}
