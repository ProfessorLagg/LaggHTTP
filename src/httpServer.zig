const builtin = @import("builtin");
const std = @import("std");

const httpContextNs = @import("httpContext.zig");
const HttpContextOptions = httpContextNs.HttpContextOptions;
const HttpContext = httpContextNs.HttpContext;

const Log = std.log.scoped(.HttpServer);
const PerfLog = std.log.scoped(.Perf);

pub const HttpServerOptions = struct {
    ctx: HttpContextOptions = .{},
    listenOptions: std.net.Address.ListenOptions = .{
        .reuse_address = true,
        .reuse_port = true,
    },
};

pub fn HttpServer(comptime opt: HttpServerOptions) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        address: std.net.Address,

        shouldRun: std.Thread.ResetEvent = .{},

        pub fn init(allocator: std.mem.Allocator, address: std.net.Address) Self {
            return Self{
                .allocator = allocator,
                .address = address,
            };
        }
        pub fn initParseIp(allocator: std.mem.Allocator, addressString: []const u8, port: u16) !Self {
            const addr = try std.net.Address.parseIp(addressString, port);
            return Self.init(allocator, addr);
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
        fn schedule(self: *Self, connection: std.net.Server.Connection) !void {
            const start = std.time.nanoTimestamp();
            var ctx: HttpContext(opt.ctx) = try HttpContext(opt.ctx).init(self.allocator, connection);
            ctx.response.statusCode = .NotFound;
            try ctx.response.send(connection.stream);
            ctx.deinit();
            connection.stream.close();
            const duration_ns = std.time.nanoTimestamp() - start;
            total_schedule_time += @floatFromInt(duration_ns);
            total_schedule_runs += 1.0;
            PerfLog.info("HttpServer.schedule took {d} ns | mean: {d:.0}", .{ duration_ns, total_schedule_mean_time() });
        }

        pub fn listen(self: *Self) !void {
            var listener: std.net.Server = try self.address.listen(opt.listenOptions);
            defer listener.deinit();
            self.shouldRun.set();

            Log.info("HttpServer listening on address {any}", .{self.address});

            while (self.shouldRun.isSet()) {
                const connection: std.net.Server.Connection = try listener.accept();
                self.schedule(connection) catch |err| {
                    std.log.err("{any}\n{any}", .{ err, @errorReturnTrace() });
                };
            }
        }
    };
}

test HttpServer {
    _ = HttpServer(.{});
}
