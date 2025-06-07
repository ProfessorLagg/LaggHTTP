const builtin = @import("builtin");
const std = @import("std");

const utils = @import("utils.zig");
const tcp = @import("tcp.zig");
const httpContextNs = @import("httpContext.zig");
const HttpContextOptions = httpContextNs.HttpContextOptions;
const HttpContext = httpContextNs.HttpContext;
const HttpRequestOptions = httpContextNs.HttpRequestOptions;
const HttpRequest = httpContextNs.HttpRequest;
const HttpHeaderField = httpContextNs.HttpHeaderField;
const HttpResponse = httpContextNs.HttpResponse;
const HttpRequestHandler = httpContextNs.HttpRequestHandler;
const HttpStatusCode = httpContextNs.HttpStatusCode;

const log = std.log.scoped(.HttpServer);
const perfLog = std.log.scoped(.Perf);

pub const HttpServerOptions = struct {
    ctx: HttpContextOptions = .{},
    listenOptions: std.net.Address.ListenOptions = .{
        .reuse_address = true,
        .reuse_port = true,
    },

    handlers: []const HttpRequestHandler = blk: {
        var r: []const HttpRequestHandler = undefined;
        r.len = 0;
        break :blk r;
    },
};

const DefaultErrorHandler = struct {
    fn getErrorHtml(allocator: std.mem.Allocator, status_code: HttpStatusCode, msg: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "<h1>Error {d}</h1><br><span>{s}</span>",
            .{ @intFromEnum(status_code), msg },
        );
    }

    fn handle(ctx: ?*anyopaque, http: *HttpContext) !bool {
        std.debug.assert(ctx == null);
        const statusCode: HttpStatusCode = http.response.statusCode;
        const statusCodeValue: u16 = statusCode.value();
        std.debug.assert(statusCode.isError());

        const req_content_type: ?HttpHeaderField = http.request.getField("Content-Type");
        const isHtml = req_content_type != null and utils.strings.streql("text/html", req_content_type.?.val);
        if (isHtml) {
            try http.response.setHeader("Content-Type", "text/html");
            http.response.body = try getErrorHtml(http.response.allocator, .NotFound, "page not found");
        }

        log.warn("Sending HTTP error {d}", .{statusCodeValue});
        try http.send();

        return true;
    }

    pub fn handler() HttpRequestHandler {
        return HttpRequestHandler{ .context = null, .handleFn = &DefaultErrorHandler.handle };
    }
};

pub fn HttpServer(comptime opt: HttpServerOptions) type {
    return struct {
        /// returns true if the route
        const Self = @This();

        allocator: std.mem.Allocator,
        address: tcp.TCPListener.IpAddress,
        port: u16,

        shouldRun: std.Thread.ResetEvent = .{},

        errorHandler: HttpRequestHandler = DefaultErrorHandler.handler(),

        pub fn init(allocator: std.mem.Allocator, address: tcp.TCPListener.IpAddress, port: u16) Self {
            return Self{
                .allocator = allocator,
                .address = address,
                .port = port,
            };
        }
        pub fn initPublicHttp(allocator: std.mem.Allocator) Self {
            const addr: std.net.Address = comptime std.net.Address.parseIp("0.0.0.0", 80) catch @compileError("Could not parse IP");
            return Self.init(allocator, addr);
        }
        pub fn initLocalHttp(allocator: std.mem.Allocator) Self {
            const addr: std.net.Address = comptime std.net.Address.parseIp("127.0.0.1", 80) catch @compileError("Could not parse IP");
            return Self.init(allocator, addr);
        }
        pub fn deinit(self: *Self) void {
            _ = &self;
        }

        var total_schedule_time: f64 = 0;
        var total_schedule_runs: f64 = 0;
        inline fn total_schedule_mean_time() f64 {
            return total_schedule_time / total_schedule_runs;
        }
        fn handleRequest(self: *Self, http: *HttpContext) !void {
            var i: usize = 0;
            var handled: bool = false;
            while (!handled and i < opt.handlers.len) : (i += 1) {
                handled = opt.handlers[i](http) catch |outer_err| {
                    // TODO handle client closed
                    log.warn("Server error: {any}{any}", .{ outer_err, @errorReturnTrace() });
                    http.response.statusCode = HttpStatusCode.fromValue(503);

                    _ = self.errorHandler.handle(http) catch |inner_err| {
                        std.log.err("Sending error response failed: {any}{any}", .{ inner_err, @errorReturnTrace() });
                    };
                };
            }
            if (!handled) {
                http.response.statusCode = HttpStatusCode.fromValue(404);
                _ = try self.errorHandler.handle(http);
            }
            http.deinit();
            try http.connection.close();
        }
        fn schedule(self: *Self, connection: tcp.TCPConnection) !void {
            const start = std.time.nanoTimestamp();
            var ctx: HttpContext = try HttpContext.init(opt.ctx, self.allocator, connection);

            // TODO this is not going to fly once i start multi threading
            try self.handleRequest(&ctx);

            const duration_ns = std.time.nanoTimestamp() - start;
            total_schedule_time += @floatFromInt(duration_ns);
            total_schedule_runs += 1.0;
            perfLog.info("HttpServer.schedule took {d} ns | mean: {d:.0}", .{ duration_ns, total_schedule_mean_time() });
        }

        pub fn listen(self: *Self) !void {
            var listener: tcp.TCPListener = try tcp.TCPListener.init(self.address, self.port);
            defer listener.deinit();

            try listener.bind();
            try listener.listen();

            log.info("HttpServer listening on address {any}", .{self.address});
            self.shouldRun.set();
            while (self.shouldRun.isSet()) {
                const connection = listener.accept() catch |err| {
                    @branchHint(.cold);
                    log.err("{any}\n{any}", .{ err, @errorReturnTrace() });
                    continue;
                };
                self.schedule(connection) catch |err| {
                    @branchHint(.cold);
                    log.err("{any}\n{any}", .{ err, @errorReturnTrace() });
                    continue;
                };
            }
        }
    };
}

test HttpServer {
    _ = HttpServer(.{});
}
