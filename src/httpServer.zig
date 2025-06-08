const builtin = @import("builtin");
const std = @import("std");
const ThreadPool = std.Thread.Pool;

const utils = @import("utils.zig");
const tcp = @import("tcp.zig");
const httpContextNs = @import("httpContext.zig");
const HttpContextOptions = httpContextNs.HttpContextOptions;
const HttpContext = httpContextNs.HttpContext;
const HttpRequestOptions = httpContextNs.HttpRequestOptions;
const HttpRequest = httpContextNs.HttpRequest;
const HttpHeader = httpContextNs.HttpHeader;
const HttpResponse = httpContextNs.HttpResponse;
const HttpRequestHandler = httpContextNs.HttpRequestHandler;
const HttpStatusCode = httpContextNs.HttpStatusCode;

const log = std.log.scoped(.HttpServer);
const PerfLog = std.log.scoped(.Perf);

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

        const req_content_type: ?HttpHeader = http.request.getField("Content-Type");
        const isHtml = req_content_type != null and utils.strings.streql("text/html", req_content_type.?.valstr());
        if (isHtml) {
            try http.response.headers.set("Content-Type", "text/html");
            http.response.body = try getErrorHtml(http.allocator, .NotFound, "page not found");
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

        fn handleRequest(self: *const Self, http: *HttpContext) !void {
            var i: usize = 0;
            var handled: bool = false;
            while (!handled and i < opt.handlers.len) : (i += 1) {
                handled = opt.handlers[i](http) catch |outer_err| {
                    // TODO handle client closed
                    log.warn("Server error: {any}{any}", .{ outer_err, @errorReturnTrace() });
                    http.response.statusCode = HttpStatusCode.fromValue(503);

                    _ = self.errorHandler.handle(http) catch |inner_err| {
                        log.err("Sending error response failed: {any}{any}", .{ inner_err, @errorReturnTrace() });
                    };
                };
            }
            if (!handled) {
                http.response.statusCode = HttpStatusCode.fromValue(404);
                _ = self.errorHandler.handle(http) catch |inner_err| {
                    log.err("Sending error response failed: {any}{any}", .{ inner_err, @errorReturnTrace() });
                };
            }
            http.deinit();
            http.connection.close() catch |err| {
                log.warn("error when closing http connection: {any}{any}", .{ err, @errorReturnTrace() });
            };
        }
        fn handleRequestMultiThread(self: *const Self, connection: tcp.TCPConnection) void {
            const start = std.time.nanoTimestamp();
            var http: HttpContext = HttpContext.init(opt.ctx, self.allocator, connection) catch |err| {
                @branchHint(.unlikely);
                log.warn("{any}", .{err});
                return;
            };
            var i: usize = 0;
            var handled: bool = false;
            while (!handled and i < opt.handlers.len) : (i += 1) {
                handled = opt.handlers[i](&http) catch |outer_err| {
                    // TODO handle client closed
                    log.warn("Server error: {any}{any}", .{ outer_err, @errorReturnTrace() });
                    http.response.statusCode = HttpStatusCode.fromValue(503);

                    _ = self.errorHandler.handle(&http) catch |inner_err| {
                        log.err("Sending error response failed: {any}{any}", .{ inner_err, @errorReturnTrace() });
                    };
                };
            }
            if (!handled) {
                http.response.statusCode = HttpStatusCode.fromValue(404);
                _ = self.errorHandler.handle(&http) catch |inner_err| {
                    log.err("Sending error response failed: {any}{any}", .{ inner_err, @errorReturnTrace() });
                };
            }
            http.deinit();
            http.connection.close() catch |err| {
                log.warn("error when closing http connection: {any}{any}", .{ err, @errorReturnTrace() });
            };

            const duration_ns = std.time.nanoTimestamp() - start;
            PerfLog.info("HttpServer.handleRequestMultiThread;{d}", .{duration_ns});
        }

        pub fn listen(self: *Self) !void {
            var listener: tcp.TCPListener = try tcp.TCPListener.init(self.address, self.port);
            defer listener.deinit();

            try listener.bind();
            try listener.listen();

            var waitGroup: std.Thread.WaitGroup = .{};
            var threadPool: ThreadPool = undefined;
            try threadPool.init(.{
                .allocator = self.allocator,
                .n_jobs = try std.Thread.getCpuCount(),
            });

            defer {
                waitGroup.finish();
                threadPool.deinit();
            }

            log.info("HttpServer listening on address {any}", .{self.address});
            self.shouldRun.set();
            while (self.shouldRun.isSet()) {
                const connection = listener.accept() catch |err| {
                    @branchHint(.cold);
                    log.err("{any}\n{any}", .{ err, @errorReturnTrace() });
                    continue;
                };
                try threadPool.spawn(handleRequestMultiThread, .{ self, connection });
                // threadPool.spawnWg(&waitGroup, handleRequestMultiThread, .{ self, connection });
            }
        }
    };
}

test HttpServer {
    _ = HttpServer(.{});
}
