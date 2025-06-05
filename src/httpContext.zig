const builtin = @import("builtin");
const std = @import("std");
const bytesToValue = std.mem.bytesToValue;

const sso = @import("sso.zig");
const SSO = sso.SSO;
const SSOMap = sso.SSOMap;

const utils = @import("utils.zig");
const VTableWriter = utils.io.VTableWriter;

const offsetNs = @import("offset.zig");
usingnamespace offsetNs;

const DateTime = @import("dateTime.zig");

const Log = std.log.scoped(.HttpContext);
const PerfLog = std.log.scoped(.Perf);

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
            const start = std.time.nanoTimestamp();
            var result: Context = Context{
                .allocator = allocator,
                .connection = connection,
                .request = undefined,
                .response = undefined,
            };
            errdefer result.deinit();
            result.request = try Request.init(result.allocator, connection.stream);
            result.response = try Response.init(result.allocator);

            const duration_ns = std.time.nanoTimestamp() - start;
            PerfLog.info("HttpContext.init took {d} ns", .{duration_ns});
            return result;
        }

        pub fn deinit(self: *Context) void {
            const start = std.time.nanoTimestamp();
            self.request.deinit(self.allocator);
            self.response.deinit();
            const duration_ns = std.time.nanoTimestamp() - start;
            PerfLog.info("HttpContext.deinit took {d} ns", .{duration_ns});
        }
    };
}

// === REQUEST ===
pub const HttpRequestOptions = struct {
    /// Maximum size of the Request line and Headers
    max_headers_size: u16 = 8192,
    /// Maximum size of the request body
    max_body_size: u32 = 1_073_741_824,

    // TODO Check that max_headers_size is not smaller than max_requestLine_size
};

pub fn HttpRequest(comptime settings: HttpRequestOptions) type {
    return struct {
        pub const HttpRequestError = error{
            RequestLineTooLong,
            MalformedRequestLine,

            HeaderTooLong,
            MalformedHeader,

            BodyTooLong,
        };
        const EmptyRequest: HttpRequest(settings) = .{
            .header = undefined,
            .requestLine = undefined,
            .method = undefined,
            .path = undefined,
            .version = undefined,
            .rawFields = undefined,
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
            const start: usize = utils.strings.indexOf(fields, key) orelse return null;
            var slice = fields[start..];
            const end: usize = utils.strings.indexOf(slice, "\r\n") orelse slice.len;
            slice = slice[0..end];
            const splitIndex: usize = utils.strings.indexOf(slice, ": ") orelse return null;
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

        const RegisteredNurse = "\r\n";
        const RegisteredNurse_u32: u32 = blk: {
            var r: u32 = 0;
            var b = std.mem.asBytes(&r);
            b[0] = RegisteredNurse[0];
            b[1] = RegisteredNurse[1];
            break :blk r;
        };
        const HeaderBodySeperator = RegisteredNurse ++ RegisteredNurse;
        const HeaderBodySeperator_u64: u64 = blk: {
            var r: u64 = 0;
            var b = std.mem.asBytes(&r);
            b[0] = HeaderBodySeperator[0];
            b[1] = HeaderBodySeperator[1];
            b[2] = HeaderBodySeperator[2];
            b[3] = HeaderBodySeperator[3];
            break :blk r;
        };

        const MethodMinLen: comptime_int = 1;
        const PathMinLen: comptime_int = 1;
        const VersionMinLen: comptime_int = 6;
        /// Minimum length of the request line (excluding the \r\n at the end)
        const RequestLineMinLen: comptime_int = MethodMinLen + 1 + PathMinLen + 1 + VersionMinLen;

        pub fn init(allocator: std.mem.Allocator, stream: std.net.Stream) !HttpRequest(settings) {
            const start = std.time.nanoTimestamp();
            var result: HttpRequest(settings) = (&EmptyRequest).*;
            var buffer: [settings.max_headers_size]u8 = undefined;

            var slice: []const u8 = buffer[0..];
            slice.len = try stream.read(buffer[0..]);

            if (slice.len == buffer.len and bytesToValue(u64, slice[slice.len - 4 ..]) != HeaderBodySeperator_u64) {
                return HttpRequestError.HeaderTooLong;
            }

            Log.debug("initial read:\n--- len:{d} ---\n{s}\n---", .{ slice.len, slice });

            const headers_end: usize = std.mem.indexOf(u8, slice, HeaderBodySeperator) orelse return HttpRequestError.MalformedHeader;
            result.header = try utils.mem.clone(u8, allocator, slice[0..headers_end]);
            errdefer allocator.free(result.header);
            Log.debug("parsed result.header", .{});

            if (result.header.len < RequestLineMinLen + 2) return HttpRequestError.MalformedRequestLine;
            result.requestLine = result.header[0..];
            result.requestLine.len = std.mem.indexOf(u8, result.requestLine, RegisteredNurse) orelse return HttpRequestError.MalformedRequestLine;
            Log.debug("parsed result.requestLine", .{});

            result.method = result.requestLine[0..];
            result.method.len = std.mem.indexOfScalar(u8, result.method, ' ') orelse {
                Log.err("request line \"{s}\" missing method", .{result.requestLine});
                return HttpRequestError.MalformedRequestLine;
            };
            Log.debug("parsed result.method", .{});

            result.path = result.requestLine[result.method.len..];
            result.path.len = std.mem.indexOfScalar(u8, result.path, ' ') orelse {
                Log.err("request line \"{s}\" missing path", .{result.requestLine});
                return HttpRequestError.MalformedRequestLine;
            };
            Log.debug("parsed result.path", .{});

            result.version = result.requestLine[result.path.len..];
            if (result.version.len < VersionMinLen) return {
                Log.err("request line \"{s}\" missing version", .{result.requestLine});
                return HttpRequestError.MalformedRequestLine;
            };
            Log.debug("parsed result.version", .{});

            result.rawFields = result.header[result.requestLine.len..];
            Log.debug("parsed result.rawFields", .{});

            // Body
            var body: []u8 = try utils.mem.clone(u8, allocator, slice[headers_end..]);
            if (slice.len < buffer.len) {
                // entire body is in buffer
                result.body = try utils.mem.clone(u8, allocator, slice[headers_end..]);
            } else {
                // i gotta read in the remaining body bytes
                while (true) {
                    const pre_len: usize = body.len;
                    slice.len = try stream.read(buffer[0..]);
                    try utils.mem.ensureResize(u8, allocator, &body, slice.len + pre_len);
                    @memcpy(body[pre_len..], slice);
                    if (slice.len < buffer.len) break;
                }
                result.body = body;
            }

            var body_len: usize = slice.len;
            var body_fragments = std.ArrayList([]const u8).init(allocator);
            defer body_fragments.deinit();
            try body_fragments.append(try utils.mem.clone(u8, allocator, slice));
            body_len += slice.len;
            while (slice.len == buffer.len) {
                slice.len = try stream.read(buffer[0..]);
                try body_fragments.append(try utils.mem.clone(u8, allocator, slice));
                body_len += slice.len;
            }
            if (body_len > 0) {
                const result_body: []u8 = try allocator.alloc(u8, body_len);
                var body_slice = result_body[0..];
                const items = body_fragments.items;
                for (0..items.len) |i| {
                    const fragment = items[i];
                    defer allocator.free(fragment);
                    @memcpy(body_slice[0..fragment.len], fragment);
                    body_slice = body_slice[fragment.len..];
                }
            }
            Log.debug("parsed request.body", .{});

            const duration_ns = std.time.nanoTimestamp() - start;
            PerfLog.info("Parsing request took {d} ns", .{duration_ns});
            return result;
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
            const vclone = try utils.mem.clone(u8, self.allocator, val);
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

        fn writeHeaderFields(self: *const Self, writer: std.net.Stream.Writer) !void {
            var iter = self.headers.iterator();
            while (iter.next()) |entry| {
                try std.fmt.format(writer, "{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        }
        fn writeStatusLine(self: *const Self, writer: std.net.Stream.Writer) !void {
            try std.fmt.format(writer, "{s} {d} {s}\r\n", .{ versionString, @intFromEnum(self.statusCode), @tagName(self.statusCode) });
        }
        pub fn send(self: *Self, stream: std.net.Stream) !void {
            const start = std.time.nanoTimestamp();
            var writer: std.net.Stream.Writer = stream.writer();
            try self.writeStatusLine(writer);
            try self.setDateHeader();
            try self.writeHeaderFields(writer);
            if (self.body != null) {
                _ = try writer.write("\r\n"[0..]);
                _ = try writer.write(self.body.?[0..]);
            }
            const duration_ns = std.time.nanoTimestamp() - start;
            PerfLog.info("Sending response took {d} ns", .{duration_ns});
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
