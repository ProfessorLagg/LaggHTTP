const std = @import("std");
const log = std.log.scoped(.HttpServer);
const HttpRequest = @import("httpRequest.zig").HttpRequest;
const HttpResponse = @import("httpResponse.zig").HttpResponse;

pub const HttpServer = @This();
pub const RequestHandlerFn = (fn (request: *HttpRequest, response: *HttpResponse) anyerror!void);
pub const HttpServerConfig: type = struct {
    allocator: std.mem.Allocator,
    addr: [4]u8 = .{ 0, 0, 0, 0 },
    port: u16 = 80,
};
pub const RequestContext = struct { // NO FOLD
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    request: HttpRequest,
    response: HttpResponse,
    connection: std.net.Server.Connection,

    pub fn accept(allocator: std.mem.Allocator, server: *std.net.Server) !RequestContext {
        var r = RequestContext{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .allocator = undefined,
            .request = undefined,
            .response = undefined,
            .connection = undefined,
        };

        r.allocator = r.arena.allocator();
        r.response = HttpResponse.init(r.allocator);
        r.connection = try server.accept();
        var reader = r.connection.stream.reader();
        r.request = HttpRequest.initReader(r.allocator, reader.any());
        return r;
    }

    pub fn deinit(self: *RequestContext) void {
        self.arena.deinit();
    }
};
/// Type of request handler map
const THandlerMap: type = std.StringArrayHashMap(*const RequestHandlerFn);
const TRequestQueue: type = std.DoublyLinkedList(RequestContext);

allocator: std.mem.Allocator,
address: std.net.Address,

requestQueueLock: std.Thread.Mutex = .{},
requestQueue: TRequestQueue,

requestHandlersLock: std.Thread.Mutex = .{},
requestHandlers: THandlerMap,

// TODO TCP Listener thread
listenTokenLock: std.Thread.Mutex = .{},
listenToken: bool = true,
listenThread: ?std.Thread,

pub fn init(allocator: std, config: HttpServerConfig) HttpServer {
    return HttpServer{ // NO FOLD
        .allocator = allocator,
        .address = std.net.Address.initIp4(config.addr, config.port),
        .requestHandlers = THandlerMap.init(allocator),
        .requestQueue = TRequestQueue{},
    };
}

pub fn deinit(self: *HttpServer) void {
    self.listenTokenLock.lock();
    self.listenToken = false;
    self.listenTokenLock.unlock();
    _ = &self;
}

/// Handles the route using the the specified handler function.
/// Routes are case-sensitive
pub fn addRequestHandler(self: *HttpServer, route: []const u8, handler: *const RequestHandlerFn) bool {
    std.debug.assert(!self.requestHandlers.contains(route));
    self.requestHandlers.put(route, handler);
}

fn listen(self: *HttpServer) !void {
    var server: std.net.Server = try self.address.listen(.{});
    defer server.deinit();
    log.info("Server listening on {any}", .{self.address});

    while (true) {
        self.listenTokenLock.lock();
        if (self.listenToken == false) {
            self.listenTokenLock.unlock();
            break;
        }
        self.listenTokenLock.unlock();

        var node: *TRequestQueue.Node = try self.allocator.create(TRequestQueue.Node);
        node.data = RequestContext.accept(self.allocator, &server);
        self.requestQueueLock.lock();
        self.requestQueue.append(node);
        self.requestQueueLock.unlock();
    }
}

pub fn run(self: *HttpServer) !void {
    self.listenThread = try std.Thread.spawn(.{
        .allocator = self.allocator,
    }, HttpServer.listen, .{self});
}
