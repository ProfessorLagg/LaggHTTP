const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.HttpServer);
const HttpRequest = @import("httpRequest.zig").HttpRequest;
const HttpResponse = @import("httpResponse.zig").HttpResponse;
const utils = @import("utils.zig");
const memutils = utils.mem;
const Offset = utils.Offset;

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
        r.request = try HttpRequest.initReader(r.allocator, reader.any());
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

requestHandlersLock: std.Thread.Mutex = .{},
requestHandlers: THandlerMap,

requestQueueLock: std.Thread.Mutex = .{},
requestQueue: TRequestQueue,

// TODO TCP Listener thread
listenTokenLock: std.Thread.Mutex = .{},
listenToken: bool = true,
listenThread: ?std.Thread = null,

pub fn init(config: HttpServerConfig) HttpServer {
    return HttpServer{ // NO FOLD
        .allocator = config.allocator,
        .address = std.net.Address.initIp4(config.addr, config.port),
        .requestHandlers = THandlerMap.init(config.allocator),
        .requestQueue = TRequestQueue{},
    };
}

pub fn deinit(self: *HttpServer) void {
    self.listenTokenLock.lock();
    self.listenToken = false;
    self.listenTokenLock.unlock();
    if (self.listenThread != null) {
        self.listenThread.?.join();
    }
    // TODO handle final requests
    self.requestHandlers.deinit();
    _ = &self;
}

/// Handles the route using the the specified handler function.
/// Routes are case-sensitive
pub fn addRequestHandler(self: *HttpServer, route: []const u8, handler: *const RequestHandlerFn) bool {
    std.debug.assert(!self.requestHandlers.contains(route));
    self.requestHandlers.put(route, handler) catch |err| {
        log.warn("{}", .{err});
        return false;
    };
    return true;
}

fn startTCP(self: *HttpServer) !std.net.Server {
    const server: std.net.Server = try self.address.listen(.{});
    log.info("Server started on {any}", .{self.address});
    return server;
}

fn listen(self: *HttpServer) !void {
    var server = self.startTCP();
    defer server.deinit();

    while (true) {
        self.listenTokenLock.lock();
        if (self.listenToken == false) {
            self.listenTokenLock.unlock();
            break;
        }
        self.listenTokenLock.unlock();

        var node: *TRequestQueue.Node = try self.allocator.create(TRequestQueue.Node);
        node.data = try RequestContext.accept(self.allocator, &server);
        self.requestQueueLock.lock();
        self.requestQueue.append(node);
        self.requestQueueLock.unlock();
    }
}

fn runSingleThread(self: *HttpServer) !void {
    // https://www.rfc-editor.org/rfc/rfc9110#section-4.1-5
    const readbuffer_size = 4096 * 2;
    var readbuffer_barr: [readbuffer_size]u8 = undefined;
    const readbuffer: []u8 = readbuffer_barr[0..];

    var tcp = try self.startTCP();
    defer tcp.deinit();

    outer: while (true) {
        const connection = tcp.accept() catch |err| {
            log.err("Could not accept connection due to error: {}", .{err});
            continue :outer;
        };

        const read_size: usize = connection.stream.read(readbuffer) catch |err| {
            log.warn("Could not read from connection to {} due to err: {}", .{ connection.address, err });
            // TODO Write Error Response
            connection.stream.close();
            continue :outer;
        };
        const read_bytes: []const u8 = readbuffer[0..read_size];

        const request_line_len = std.mem.indexOf(u8, read_bytes, "\r\n") orelse {
            log.warn("Request line was too long or not present", .{});
            // TODO Write Error Response
            connection.stream.close();
            continue :outer;
        };
        const request_line: []const u8 = read_bytes[0..request_line_len];

        // TODO Read the `method`, `route` and `version` fields from the request
        _ = &request_line;
    }
}

fn runMultiThread(self: *HttpServer) !void {
    self.listenThread = try std.Thread.spawn(.{
        .allocator = self.allocator,
    }, HttpServer.listen, .{self});

    // TODO Start request handlers from queue
    while (true) {
        if (self.requestQueue.len == 0) continue;

        self.requestQueueLock.lock();
        const node = self.requestQueue.pop();
        self.requestQueueLock.unlock();
        if (node == null) continue;

        var ctx: RequestContext = node.?.data;
        const handlerFn: ?*const RequestHandlerFn = self.requestHandlers.get(ctx.request.route);

        if (handlerFn == null) {
            ctx.response.status = HttpResponse.StatusCode.NotFound;
        } else {
            try @call(std.builtin.CallModifier.auto, handlerFn.?, .{ &ctx.request, &ctx.response });
        }

        const outer_writer = ctx.connection.stream.writer();
        const inner_writer = outer_writer.any();
        try ctx.response.write(inner_writer);
        ctx.connection.stream.close();
    }
}

pub fn run(self: *HttpServer) !void {
    if (builtin.single_threaded) {
        try self.runSingleThread();
    } else {
        try self.runMultiThread();
    }
}
