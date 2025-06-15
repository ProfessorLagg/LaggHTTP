const builtin = @import("builtin");
const std = @import("std");

const utils = @import("utils.zig");

const URI = @import("uri.zig").URI;

const httpNs = @import("httpContext.zig");
const HttpContext = httpNs.HttpContext;
const HttpRequestHandler = httpNs.HttpRequestHandler;

pub const HTTPFileHandler = struct {
    allocator: std.mem.Allocator,
    root: std.fs.Dir,

    pub fn init(allocator: std.mem.Allocator, rootPath: []const u8) !HTTPFileHandler {
        var r = HTTPFileHandler{ .allocator = allocator, .root = undefined };
        const rootAbspath = try utils.fs.abspath(allocator, rootPath);
        defer allocator.free(rootAbspath);
        r.root = utils.fs.openMakeDirAbsolute(rootAbspath, .{ .access_sub_paths = true, .iterate = false, .no_follow = false });
        return r;
    }
    pub fn deinit() void {}

    pub fn handler(self: *const HTTPFileHandler) HttpRequestHandler {
        return HttpRequestHandler{
            .context = @constCast(self),
            .handleFn = handleFn,
        };
    }

    // handleFn: *const fn (?*anyopaque, *HttpContext) anyerror!bool,
    fn handleFn(selfptr: ?*anyopaque, ctx: *HttpContext) !bool {
        std.debug.assert(selfptr != null);
        const self: *HTTPFileHandler = @ptrCast(selfptr);
        const uri: URI = URI.parse(ctx.request.target);

        _ = &self;
        _ = &uri;
        // TODO finish this func
        @compileError("Not implemented");
    }
};
