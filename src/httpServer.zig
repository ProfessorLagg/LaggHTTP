const builtin = @import("builtin");
const std = @import("std");

const httpContextNs = @import("httpContext.zig");
const HttpContextOptions = httpContextNs.HttpContextOptions;
const HttpContext = httpContextNs.HttpContext;

pub const HttpServerOptions = struct {
    ctx: HttpContextOptions = .{},
    listenOptions: std.net.Address.ListenOptions = .{},
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

        fn schedule(self: *Self, connection: std.net.Server.Connection) !void {
            var ctx: HttpContext(opt.ctx) = try HttpContext(opt.ctx).init(self.allocator, connection);

            ctx.deinit();
        }

        pub fn listen(self: *Self) !void {
            var listener: std.net.Server = try self.address.listen(opt.listenOptions);
            defer listener.deinit();
            self.shouldRun.set();

            while (self.shouldRun.isSet()) {
                const connection: std.net.Server.Connection = try listener.accept();
                try self.schedule(connection);
            }
        }
    };
}

test HttpServer {
    _ = HttpServer(.{});
}
