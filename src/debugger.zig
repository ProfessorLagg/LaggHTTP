const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.Debugger);
const utils = @import("utils.zig");
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
        // HttpResponse.setHeader breaks if this is not set to debug
        .{ .scope = .HttpResponse, .level = .debug },
    },
};

pub fn main() !void {
    try debug_httpServer();
}

fn debug_httpRequest() !void {
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const allocator = gpa_alloc.allocator();

    const addr: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);
    var server: std.net.Server = try addr.listen(.{});

    log.info("Server listening on {any}", .{addr});
    while (true) {
        var client = try server.accept();
        defer client.stream.close();
        log.info("Client connected: {}", .{client.address});

        const client_reader = client.stream.reader();
        const client_writer = client.stream.writer();

        var request: LaggHTTP.HttpRequest = try LaggHTTP.HttpRequest.initReader(allocator, client_reader.any());
        defer request.deinit();
        log.info("HttpRequest:\n{}", .{request});
        try std.fmt.format(client_writer, "HTTP/1.1 200 OK\r\n\r\n", .{});
    }
}

fn debug_tcp() !void {
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const gpa = gpa_alloc.allocator();

    const addr: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);
    var server: std.net.Server = try addr.listen(.{});

    log.info("Server listening on {any}", .{addr});

    const buf_size: comptime_int = 65536;
    const read_buf: []u8 = try gpa.alloc(u8, buf_size);
    defer gpa.free(read_buf);

    while (true) {
        log.debug("Waiting for client to connect", .{});
        var client = try server.accept();
        defer client.stream.close();

        log.info("Client connected: {}", .{client.address});

        const client_reader = client.stream.reader();
        const client_writer = client.stream.writer();

        const msg_len = try client_reader.read(read_buf);
        const msg = read_buf[0..msg_len];

        log.info("Recieved message: \"{}\"", .{std.zig.fmtEscapes(msg)});

        try client_writer.writeAll(msg);
    }
}

fn debug_httpServer() !void {
    const HttpServer = LaggHTTP.HttpServer;
    const HttpRequest = LaggHTTP.HttpRequest;
    const HttpResponse = LaggHTTP.HttpResponse;

    const handlers = struct {
        pub fn rootHandler(request: *HttpRequest, response: *HttpResponse) !void {
            std.debug.assert(utils.mem.equalSlices(u8, request.route, "/"[0..]));
            std.debug.assert(utils.mem.equalSlices(u8, request.version, "HTTP/1.1"[0..]));
            try response.setHeader("Content-Type", "text/html; charset=UTF-8");
        }
    };

    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa_alloc.deinit() == .ok);
    defer _ = gpa_alloc.deinit();
    const allocator = gpa_alloc.allocator();

    // var heap_alloc = std.heap.HeapAllocator.init();
    // defer heap_alloc.deinit();
    // const allocator = heap_alloc.allocator();

    var server: HttpServer = HttpServer.init(.{
        .allocator = allocator,
        .addr = .{ 127, 0, 0, 1 },
        .port = 8080,
    });
    defer server.deinit();
    _ = server.addRequestHandler("/", handlers.rootHandler);
    try server.run();
}
