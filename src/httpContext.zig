const builtin = @import("builtin");
const std = @import("std");

const utils = @import("utils.zig");

const offsetNs = @import("offset.zig");
usingnamespace offsetNs;

// === TYPES ===
pub const HttpHeaderField = struct {
    key: []const u8,
    val: []const u8,
};

// === CONTEXT ===
pub const HttpContextOptions = struct {
    request: HttpRequestOptions = .{},
    response: HttpResponseOptions = .{},
};
pub fn HttpContext(comptime settings: HttpContextOptions) type {
    return struct {
        const Context = @This();
        const Request = HttpRequest(settings.request);
        const Response = HttpResponse(settings.response);

        arena: std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,
        request: Request,
        response: Response,

        pub fn init(allocator: std.mem.Allocator, stream: std.net.Stream) !Context {
            var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(allocator);
            var result: Context = Context{
                .arena = arena,
                .allocator = arena.allocator(),
                .request = undefined,
                .response = undefined,
            };
            errdefer result.deinit();
            result.request = try Request.init(result.allocator, stream.reader());
            result.response = try Response.init(result.allocator, stream.writer());
            return result;
        }

        pub fn deinit(self: *Context) void {
            self.arena.deinit();
        }
    };
}

// === REQUEST ===
pub const HttpRequestOptions = struct {
    /// Maximum size of the request line
    max_requestLine_size: u16 = 4096,
    /// Maximum size of the Headers Section
    max_headers_size: u16 = 4096,
    /// Maximum size of the request body
    max_body_size: u32 = 1_073_741_824,

    // TODO Check that max_headers_size is not smaller than max_requestLine_size
};
pub fn HttpRequest(comptime settings: HttpRequestOptions) type {
    return struct {
        pub const HttpRequestError = error{
            RequestLineTooLong,
            MalformedRequestLine,

            HeaderSegmentTooLong,
            MalformedHeaderSegment,

            BodyTooLong,
        };

        /// Contains both request line and HTTP header fields
        header: []const u8,
        requestLine: []const u8,
        method: []const u8,
        path: []const u8,
        version: []const u8,
        rawFields: []const u8,
        body: []const u8,

        fn find_field(fields: []const u8, key: []const u8) ?HttpHeaderField {
            const start: usize = utils.Strings.indexOf(fields, key) orelse return null;
            var slice = fields[start..];
            const end: usize = utils.Strings.indexOf(slice, "\r\n") orelse slice.len;
            slice = slice[0..end];
            const splitIndex: usize = utils.Strings.indexOf(slice, ": ") orelse return null;
            return HttpHeaderField{
                .key = slice[0..splitIndex],
                .val = slice[splitIndex + 2 ..],
            };
        }
        fn parse_request_line(self: *HttpRequest(settings)) !void {
            var iter = std.mem.splitScalar(u8, self.requestLine, ' ');
            self.method = iter.next() orelse return HttpRequestError.MalformedRequestLine;
            self.path = iter.next() orelse return HttpRequestError.MalformedRequestLine;
            self.version = iter.next() orelse return HttpRequestError.MalformedRequestLine;
        }

        pub fn init(allocator: std.mem.Allocator, reader: anytype) !HttpRequest(settings) {
            var header_buffer: [settings.max_requestLine_size + settings.max_headers_size]u8 = undefined;
            @memset(header_buffer[0..], 0);
            var i: usize = 2;
            header_buffer[0] = reader.readByte() catch return HttpRequestError.MalformedRequestLine;
            header_buffer[1] = reader.readByte() catch return HttpRequestError.MalformedRequestLine;
            while (!std.mem.eql(u8, header_buffer[i - 2 .. i], "\r\n")) : (i += 1) {
                if (i >= settings.max_requestLine_size) return HttpRequestError.RequestLineTooLong;
                header_buffer[i] = reader.readByte() catch return HttpRequestError.MalformedRequestLine;
            }
            const fields_start_i = i;
            while (!std.mem.eql(u8, header_buffer[i - 4 .. i], "\r\n\r\n")) : (i += 1) {
                if ((i - fields_start_i) >= settings.max_headers_size) return HttpRequestError.RequestLineTooLong;
                header_buffer[i] = reader.readByte() catch return HttpRequestError.MalformedRequestLine;
            }

            var header: []u8 = try allocator.alloc(u8, i);
            std.mem.copyForwards(u8, header, header_buffer[0..i]);

            var result: HttpRequest(settings) = .{
                .header = header,
                .requestLine = header[0 .. fields_start_i - 2],
                .rawFields = header[fields_start_i..],

                .method = header[0..0],
                .path = header[0..0],
                .version = header[0..0],
                .body = undefined,
            };
            try result.parse_request_line();

            if (find_field(result.rawFields, "Content-Length")) |field| {
                const content_length_value: usize = @intCast(utils.Strings.fastIntParse(isize, field.val));
                if (content_length_value > settings.max_body_size) return HttpRequestError.BodyTooLong;
                var body: []u8 = try allocator.alloc(u8, content_length_value);
                const body_size: usize = try reader.read(body);
                if (body.len != body_size) {
                    const temp_body: []u8 = try allocator.alloc(u8, body_size);
                    std.mem.copyForwards(u8, temp_body, body);
                    allocator.free(body);
                    body = temp_body;
                }
                result.body = body[0..];
            }

            _ = &result;
            return result;
        }
        pub fn deinit(self: *HttpRequest(settings), allocator: std.mem.Allocator) void {
            allocator.free(self.header);
            allocator.free(self.body);
        }

        /// Returns the Http Header Field with the specified key if found
        pub inline fn getField(self: *const HttpRequest(settings), key: []const u8) ?HttpHeaderField {
            return find_field(self.rawFields, key);
        }

        test init {
            const allocator = std.testing.allocator;

            const http_post = @embedFile("testdata/post.txt");
            var stream = std.io.fixedBufferStream(http_post);
            const reader = stream.reader();
            var request: HttpRequest(settings) = try HttpRequest(settings).init(reader, allocator);
            defer request.deinit(allocator);

            try std.testing.expectEqualStrings("POST", request.method);
            try std.testing.expectEqualStrings("/index.html", request.path);
            try std.testing.expectEqualStrings("HTTP/1.1", request.version);
            try std.testing.expectEqualStrings("DATADATADATADATADATADATADATADATA", request.body);
        }
    };
}

// === RESPONSE ===
pub const HttpResponseOptions = struct {};
pub fn HttpResponse(comptime settings: HttpResponseOptions) type {
    _ = &settings;
    return struct {
        pub fn init(allocator: std.mem.Allocator, writer: anytype) !HttpResponse(settings) {
            _ = &allocator;
            _ = &writer;
            return .{};
        }
    };
}

// === Tests ===
test HttpContext {
    _ = HttpContext(.{});
}
test HttpRequest {
    _ = HttpRequest(.{});
}
test HttpResponse {
    _ = HttpResponse(.{});
}
