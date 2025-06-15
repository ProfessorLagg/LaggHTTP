const builtin = @import("builtin");
const std = @import("std");

const utils = @import("utils.zig");

const URI = @import("uri.zig").URI;

const httpNs = @import("httpContext.zig");
const HttpContext = httpNs.HttpContext;
const HttpRequestHandler = httpNs.HttpRequestHandler;
const HttpStatusCode = httpNs.HttpStatusCode;

pub const HTTPFileHandler = struct {
    allocator: std.mem.Allocator,
    root: std.fs.Dir,

    pub fn defaultRootPath(allocator: std.mem.Allocator) ![]const u8 {
        const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir);
        const path_parts = [_][]const u8{
            exe_dir[0..],
            "wwwroot",
        };
        return try std.fs.path.join(allocator, &path_parts);
    }

    pub fn init(allocator: std.mem.Allocator, rootPath: []const u8) !HTTPFileHandler {
        var r = HTTPFileHandler{ .allocator = allocator, .root = undefined };
        const rootAbspath = try utils.fs.abspath(allocator, rootPath);
        defer allocator.free(rootAbspath);
        r.root = try utils.fs.openMakeDirAbsolute(rootAbspath, .{ .access_sub_paths = true, .iterate = false, .no_follow = false });
        return r;
    }
    pub fn deinit() void {}

    pub fn handler(self: *const HTTPFileHandler) HttpRequestHandler {
        return HttpRequestHandler{
            .context_ptr = @intFromPtr(self),
            .handleFn = handleFn,
        };
    }

    fn handleFn(selfptr: ?usize, ctx: *HttpContext) anyerror!bool {
        std.debug.assert(selfptr != null);
        const self: *HTTPFileHandler = @ptrFromInt(selfptr.?);
        const uri: URI = try URI.parse(ctx.request.target);
        const file_path: []const u8 = uri.path orelse "";
        const file: std.fs.File = self.root.openFile(file_path, .{}) catch |err| {
            switch (err) {
                // TODO the server is overriding this
                error.FileNotFound, error.IsDir => ctx.response.statusCode = HttpStatusCode.NotFound,
                else => ctx.response.statusCode = HttpStatusCode.InternalServerError,
            }
            return err;
        };
        defer file.close();

        try ctx.sendFile(&file);

        return true;
    }
};
