const builtin = @import("builtin");
const std = @import("std");

const sso = @import("sso.zig");
const SSO = sso.SSO;
const SSOMap = sso.SSOMap;

const utils = @import("utils.zig");
const VTableWriter = utils.io.VTableWriter;

const offsetNs = @import("offset.zig");
usingnamespace offsetNs;

const DateTime = @import("dateTime.zig");

// === TYPES ===
pub const HttpHeaderField = struct {
    key: []const u8,
    val: []const u8,

    /// Allocates a new HttpHeaderField by cloning both key and val
    pub fn asClone(allocator: std.mem.Allocator, key: []const u8, val: []const u8) !HttpHeaderField {
        return HttpHeaderField{
            .key = try utils.mem.clone(u8, allocator, key),
            .val = try utils.mem.clone(u8, allocator, val),
        };
    }
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

        allocator: std.mem.Allocator,
        connection: std.net.Server.Connection,
        request: Request,
        response: Response,

        pub fn init(allocator: std.mem.Allocator, connection: std.net.Server.Connection) !Context {
            var result: Context = Context{
                .allocator = allocator,
                .connection = connection,
                .request = undefined,
                .response = undefined,
            };
            errdefer result.deinit();
            result.request = try Request.initStream(result.allocator, connection.stream);
            result.response = try Response.init(result.allocator);
            return result;
        }

        pub fn deinit(self: *Context) void {
            self.request.deinit(self.allocator);
            self.response.deinit();
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
        body: ?[]const u8 = null,

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
            const start: i128 = std.time.nanoTimestamp();
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

            const duration_ns = std.time.nanoTimestamp() - start;
            std.log.info("Parsing request took: {d} ns", .{duration_ns});
            return result;
        }
        pub fn initStream(allocator: std.mem.Allocator, stream: std.net.Stream) !HttpRequest(settings) {
            return @This().init(allocator, stream.reader());
        }
        pub fn deinit(self: *HttpRequest(settings), allocator: std.mem.Allocator) void {
            allocator.free(self.header);
            if (self.body != null) allocator.free(self.body.?);
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
pub const HttpStatusCode = enum(u16) {
    Continue = 100,
    SwitchingProtocols = 101,
    Processing = 102,
    EarlyHints = 103,
    OK = 200,
    Created = 201,
    Accepted = 202,
    NonAuthoritativeInformation = 203,
    NoContent = 204,
    ResetContent = 205,
    PartialContent = 206,
    MultiStatus = 207,
    AlreadyReported = 208,
    IMUsed = 226,
    MultipleChoices = 300,
    MovedPermanently = 301,
    Found = 302,
    SeeOther = 303,
    NotModified = 304,
    UseProxy = 305,
    Unused = 306,
    RedirectKeepVerb = 307,
    PermanentRedirect = 308,
    BadRequest = 400,
    Unauthorized = 401,
    PaymentRequired = 402,
    Forbidden = 403,
    NotFound = 404,
    MethodNotAllowed = 405,
    NotAcceptable = 406,
    ProxyAuthenticationRequired = 407,
    RequestTimeout = 408,
    Conflict = 409,
    Gone = 410,
    LengthRequired = 411,
    PreconditionFailed = 412,
    RequestEntityTooLarge = 413,
    RequestUriTooLong = 414,
    UnsupportedMediaType = 415,
    RequestedRangeNotSatisfiable = 416,
    ExpectationFailed = 417,
    MisdirectedRequest = 421,
    UnprocessableEntity = 422,
    Locked = 423,
    FailedDependency = 424,
    UpgradeRequired = 426,
    PreconditionRequired = 428,
    TooManyRequests = 429,
    RequestHeaderFieldsTooLarge = 431,
    UnavailableForLegalReasons = 451,
    InternalServerError = 500,
    NotImplemented = 501,
    BadGateway = 502,
    ServiceUnavailable = 503,
    GatewayTimeout = 504,
    HttpVersionNotSupported = 505,
    VariantAlsoNegotiates = 506,
    InsufficientStorage = 507,
    LoopDetected = 508,
    NotExtended = 510,
    NetworkAuthenticationRequired = 511,
};
pub const HttpResponseOptions = struct {};
pub fn HttpResponse(comptime opt: HttpResponseOptions) type {
    _ = &opt;
    return struct {
        const Self = @This();
        const versionString = "HTTP/1.1";

        allocator: std.mem.Allocator,

        statusCode: HttpStatusCode = .OK,

        headers: std.StringHashMap([]const u8),
        body: ?[]const u8 = null,
        pub fn init(allocator: std.mem.Allocator) !Self {
            var r = Self{
                .allocator = allocator,
                .headers = std.StringHashMap([]const u8).init(allocator),
            };
            try r.setDateHeader();
            return r;
        }
        pub fn deinit(self: *Self) void {
            var val_iter = self.headers.valueIterator();
            while (val_iter.next()) |val_ptr| {
                self.allocator.free(val_ptr.*);
            }
            self.headers.deinit();
            if (self.body != null) self.allocator.free(self.body.?);
        }
        /// Sets a header field to the input val. val is cloned.
        pub fn setHeader(self: *Self, key: []const u8, val: []const u8) !void {
            const vclone = try utils.mem.clone(u8, &self.allocator, val);
            try self.headers.put(key, vclone);
        }

        /// Sets the HTTP Date header to now
        pub fn setDateHeader(self: *Self) !void {
            const now = DateTime.now();
            const key = "Date";
            var buf: [29]u8 = undefined;
            const value = try std.fmt.bufPrint(
                buf[0..],
                "{s}, {d:0>2} {s} {d:0>4} {d:0>2}:{d:0>2}:{d:0>2} GMT",
                .{
                    now.weekdayName3(),
                    now.day,
                    now.monthName3(),
                    now.year,
                    now.hour,
                    now.minute,
                    now.second,
                },
            );

            try self.setHeader(key[0..], value[0..]);
        }

        fn writeHeaderFields(self: *const Self, writer: anytype) !void {
            var iter = self.headers.iterator();
            while (iter.next()) |entry| {
                try std.fmt.format(writer, "{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        }
        fn writeStatusLine(self: *const Self, writer: anytype) !void {
            try std.fmt.format(writer, "{s} {d} {s}\r\n", .{ versionString, @intFromEnum(self.statusCode), @tagName(self.statusCode) });
        }
        pub fn send(self: *Self, writer: anytype) !void {
            const start = std.time.nanoTimestamp();
            var bw_struct = std.io.bufferedWriter(writer);
            var bw = bw_struct.writer();
            try self.writeStatusLine(bw);
            try self.setDateHeader();
            try self.writeHeaderFields(bw);
            if (self.body != null) {
                _ = try bw.write("\r\n"[0..]);
                _ = try bw.write(self.body.?[0..]);
            }
            try bw_struct.flush();
            const duration_ns = std.time.nanoTimestamp() - start;
            std.log.info("Sending response took {d} ns", .{duration_ns});
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
