const builtin = @import("builtin");
const std = @import("std");
const LaggHTTP = @import("LaggHTTP");

pub const std_options: std.Options = .{
    // Set the log level to info to .debug. use the scope levels instead
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .debug,
        .ReleaseSmall => .info,
        .ReleaseFast => .info,
    },
    // .log_scope_levels = &[_]std.log.ScopeLevel{
    //     .{ .scope = .SortedArrayMap, .level = .warn },
    //     .{ .scope = .DelimReader, .level = .err },
    //     .{ .scope = .Lines, .level = .err },
    //     .{ .scope = .SSO, .level = .err },
    // },
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    var server = try LaggHTTP.HttpServer(.{}).initParseIp(allocator, "127.0.0.1", 5500);
    defer server.deinit();

    try server.listen();
}
