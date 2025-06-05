const builtin = @import("builtin");
const std = @import("std");

const tcp = @import("tcp.zig");
const httpContextNs = @import("httpContext.zig");
const HttpContextOptions = httpContextNs.HttpContextOptions;
const HttpContext = httpContextNs.HttpContext;

const log = std.log.scoped(.HttpServer);
const perfLog = std.log.scoped(.Perf);

pub const HttpServerOptions = struct {
    ctx: HttpContextOptions = .{},
    listenOptions: std.net.Address.ListenOptions = .{
        .reuse_address = true,
        .reuse_port = true,
    },
};

pub fn HttpRequestHandler(comptime opt: HttpServerOptions) type {
    return struct {
        canHandle: fn (*HttpContext(opt.ctx)) bool,
        handle: fn (*HttpContext(opt.ctx)) anyerror!void,
    };
}

pub fn HttpServer(comptime opt: HttpServerOptions) type {
    return struct {
        /// returns true if the route
        const Self = @This();

        allocator: std.mem.Allocator,
        address: tcp.TCPListener.IpAddress,
        port: u16,

        shouldRun: std.Thread.ResetEvent = .{},

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
        fn schedule(self: *Self, connection: tcp.TCPConnection) !void {
            const start = std.time.nanoTimestamp();
            var ctx: HttpContext = try HttpContext.init(opt.ctx, self.allocator, connection);
            ctx.response.statusCode = .NotFound;
            try ctx.response.send(connection);
            ctx.deinit();
            try connection.close();
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
