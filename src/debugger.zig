const builtin = @import("builtin");
const std = @import("std");
const LaggHTTP = @import("root.zig");

pub const std_options: std.Options = .{
    // Set the log level to info to .debug. use the scope levels instead
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .info,
        .ReleaseSmall => .info,
        .ReleaseFast => .warn,
    },
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .HttpRequest, .level = .info },
    },
};

pub fn main() !void {
    try debug_httpRequest();
}

fn debug_httpRequest() !void {
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const allocator = gpa_alloc.allocator();

    const addr: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);
    var server: std.net.Server = try addr.listen(.{});

    std.log.info("Server listening on {any}", .{addr});
    while (true) {
        var client = try server.accept();
        defer client.stream.close();
        std.log.info("Client connected: {}", .{client.address});

        const client_reader = client.stream.reader();
        const client_writer = client.stream.writer();

        var request: LaggHTTP.HttpRequest = try LaggHTTP.HttpRequest.initReader(allocator, client_reader.any());
        defer request.deinit();
        std.log.info("HttpRequest:\n{}", .{request});
        try std.fmt.format(client_writer, "HTTP/1.1 200 OK\r\n\r\n", .{});
    }
}

fn debug_tcp() !void {
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const gpa = gpa_alloc.allocator();

    const addr: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);
    var server: std.net.Server = try addr.listen(.{});

    std.log.info("Server listening on {any}", .{addr});

    const buf_size: comptime_int = 65536;
    const read_buf: []u8 = try gpa.alloc(u8, buf_size);
    defer gpa.free(read_buf);

    while (true) {
        std.log.debug("Waiting for client to connect", .{});
        var client = try server.accept();
        defer client.stream.close();

        std.log.info("Client connected: {}", .{client.address});

        const client_reader = client.stream.reader();
        const client_writer = client.stream.writer();

        const msg_len = try client_reader.read(read_buf);
        const msg = read_buf[0..msg_len];

        std.log.info("Recieved message: \"{}\"", .{std.zig.fmtEscapes(msg)});

        try client_writer.writeAll(msg);
    }
}
