const builtin = @import("builtin");
const std = @import("std");
const LaggHTTP = @import("LaggHTTP");

pub const std_options: std.Options = .{
    // Set the log level to info to .debug. use the scope levels instead
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .debug,
        .ReleaseSmall => .err,
        .ReleaseFast => .err,
    },
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .HttpServer, .level = .info },
        .{ .scope = .HttpContext, .level = .info },
    },
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    const address: std.net.Address = std.net.Address.initIp4(.{127, 0, 0, 1}, 5500);
    var server = LaggHTTP.HttpServer(.{}).init(allocator, address);
    defer server.deinit();

    try server.listen();
}
