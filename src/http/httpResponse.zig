const std = @import("std");
const utils = @import("../utils.zig");
const log = std.log.scoped(.HttpResponse);

const HttpStatusCode = @import("httpStatuscode.zig").HttpStatusCode;

pub const HttpResponse = struct {
    /// Map type used for Headers
    const TMap = std.StringArrayHashMap([]const u8);

    /// List type used for the body segments
    const TList = std.ArrayList([]const u8);

    allocator: std.mem.Allocator,
    status: HttpStatusCode,
    headers: TMap,
    bodySegments: TList,

    pub fn init(allocator: std.mem.Allocator) HttpResponse {
        return HttpResponse{
            .allocator = allocator,
            .status = .OK,
            .headers = TMap.init(allocator),
            .bodySegments = TList.init(allocator),
        };
    }

    pub fn deinit(self: *HttpResponse) void {
        self.headers.deinit();
        if (self.body != null) {
            self.allocator.free(self.body);
        }
    }

    pub fn setHeader(self: *HttpResponse, key: []const u8, value: []const u8) !void {
        log.debug("{s}.setHeader, key = \"{s}\", value = \"{s}\"", .{ @typeName(@This()), key, value });
        try self.headers.put(key, value);
    }

    /// Appends bytes to the body of the response.
    pub fn appendBody(self: *HttpResponse, bytes: []const u8) !void {
        try self.bodySegments.append(bytes);
    }

    const registreredNurse: []const u8 = "\r\n";
    pub fn write(self: *const HttpResponse, writer: std.io.AnyWriter) !void {
        try std.fmt.format(writer, "HTTP/1.1 {d} {s}" ++ registreredNurse, .{ @intFromEnum(self.status), @tagName(self.status) });
        const header_keys = self.headers.keys();
        for (header_keys) |header_key| {
            const header_val: []const u8 = self.headers.get(header_key) orelse ""[0..];
            try std.fmt.format(writer, "{s}: {s}" ++ registreredNurse, .{ header_key, header_val });
        }

        _ = try writer.write(registreredNurse);
        for (self.bodySegments.items) |body_segment| {
            _ = try writer.write(body_segment);
        }
    }
};
