const std = @import("std");

pub const mem = struct {
    /// tries allocator.resize first, if it fails, reallocates the memory
    pub fn resize(comptime T: type, allocator: std.mem.Allocator, memory: *[]T, len: usize) !void {
        std.debug.assert(len > 0);

        if (!allocator.resize(memory.*, len)) {
            const new_memory: []T = try allocator.alloc(T, len);
            const min_len: usize = @min(memory.len, new_memory.len);
            @memcpy(new_memory[0..min_len], memory.*[0..min_len]);
            allocator.free(memory.*);
            memory.*.len = new_memory.len;
            memory.*.ptr = new_memory.ptr;
        }
    }
};
