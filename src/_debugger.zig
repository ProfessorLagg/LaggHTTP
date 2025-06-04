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
        .{ .scope = .Perf, .level = .info },
    },
};

pub fn main() !void {
    // try debugStandardHttpServer();
    try debugTCPListener();
}

fn debugTCPListener() !void {
    const listener = LaggHTTP.tcp.TCPListener{};
    _ = &listener;
}

fn debugStandardHttpServer() !void {
    // const allocator = std.heap.c_allocator;
    const address: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 5500);
    var listener: std.net.Server = try address.listen(.{});
    var buffer: [65_536]u8 = undefined;
    while (true) {
        const connection = try listener.accept();
        var server = std.http.Server.init(connection, buffer[0..]);
        var request = try server.receiveHead();
        try request.respond("", .{});
    }
}

fn debugHttpServer() !void {
    const allocator = std.heap.c_allocator;
    const address: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 5500);
    var server = LaggHTTP.HttpServer(.{}).init(allocator, address);
    defer server.deinit();

    try server.listen();
}
