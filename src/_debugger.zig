const std = @import("std");
const LaggHTTP = @import("LaggHTTP");

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    var server = try LaggHTTP.HttpServer(.{}).initParseIp(allocator, "127.0.0.1", 5500);
    defer server.deinit();

    try server.listen();
}
