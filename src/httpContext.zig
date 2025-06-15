const builtin = @import("builtin");
const std = @import("std");
const bytesToValue = std.mem.bytesToValue;

const tcp = @import("tcp.zig");
const TCPListener = tcp.TCPListener;
const TCPConnection = tcp.TCPConnection;

const URI = @import("uri.zig").URI;

const httpHeaders = @import("httpHeaders.zig");
pub const HttpHeader = httpHeaders.HttpHeader;
const HttpHeaderMap = httpHeaders.HttpHeaderMap;

const utils = @import("utils.zig");

// const offsetNs = @import("offset.zig");
// usingnamespace offsetNs;

const DateTime = @import("dateTime.zig");

const Log = std.log.scoped(.HttpContext);
const PerfLog = std.log.scoped(.Perf);

// === CONTEXT ===
pub const HttpContextOptions = struct {
    request: HttpRequestOptions = .{},
};
pub const HttpContext = struct {
    allocator: std.mem.Allocator,
    connection: TCPConnection,
    request: HttpRequest,
    response: HttpResponse,

    pub fn init(comptime settings: HttpContextOptions, allocator: std.mem.Allocator, connection: TCPConnection) !HttpContext {
        const start = std.time.nanoTimestamp();
        var result: HttpContext = HttpContext{
            .allocator = allocator,
            .connection = connection,
            .request = undefined,
            .response = undefined,
        };
        errdefer result.deinit();
        result.request = try HttpRequest.init(settings.request, result.allocator, connection);
        result.response = try HttpResponse.init(result.allocator);

        const duration_ns = std.time.nanoTimestamp() - start;
        PerfLog.info("HttpContext.init\t{d}", .{duration_ns});
        return result;
    }
    pub fn deinit(self: *HttpContext) void {
        const start = std.time.nanoTimestamp();
        self.request.deinit(self.allocator);
        self.response.deinit();
        const duration_ns = std.time.nanoTimestamp() - start;
        PerfLog.info("HttpContext.deinit\t{d}", .{duration_ns});
    }

    pub fn send(self: *HttpContext) !void {
        try self.response.send(self.connection);
    }
};

// === REQUEST ===
pub const HttpRequestOptions = struct {
    /// Maximum size of the Request line and Headers
    max_headers_size: u16 = 8192,
    /// Maximum size of the request body
    max_body_size: u32 = 1_073_741_824,

    // TODO Check that max_headers_size is not smaller than max_requestLine_size
};

pub const HttpRequest = struct {
    pub const HttpRequestError = error{
        RequestLineTooLong,
        MalformedRequestLine,

        HeaderTooLong,
        MalformedHeader,

        BodyTooLong,
    };
    const EmptyRequest: HttpRequest = .{
        .header = undefined,
        .requestLine = undefined,
        .method = undefined,
        .target = undefined,
        .version = undefined,
        .rawFields = undefined,
    };
    /// Contains both request line and HTTP header fields
    header: []const u8,
    requestLine: []const u8,
    method: []const u8,
    /// Also known as path.
    /// see [mdn](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Messages#request_targets)
    target: []const u8,
    version: []const u8,
    rawFields: []const u8,
    body: ?[]const u8 = null,

    fn find_field(fields: []const u8, key: []const u8) ?HttpHeader {
        const start: usize = utils.strings.indexOf(fields, key) orelse return null;
        var slice = fields[start..];
        const end: usize = utils.strings.indexOf(slice, "\r\n") orelse slice.len;
        slice = slice[0..end];
        const splitIndex: usize = utils.strings.indexOf(slice, ": ") orelse return null;
        return HttpHeader{
            .buf_ptr = slice.ptr,
            .buf_len = @truncate(slice.len),
            .keylen = @truncate(splitIndex),
        };
    }
    fn parse_request_line(self: *HttpRequest) !void {
        var iter = std.mem.splitScalar(u8, self.requestLine, ' ');
        self.method = iter.next() orelse return HttpRequestError.MalformedRequestLine;
        self.target = iter.next() orelse return HttpRequestError.MalformedRequestLine;
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

    pub fn init(comptime opt: HttpRequestOptions, allocator: std.mem.Allocator, stream: TCPConnection) !HttpRequest {
        const start = std.time.nanoTimestamp();
        var result: HttpRequest = (&EmptyRequest).*;
        var buffer: [opt.max_headers_size]u8 = undefined;

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

        result.target = result.requestLine[result.method.len..];
        result.target.len = std.mem.indexOfScalar(u8, result.target, ' ') orelse {
            Log.err("request line \"{s}\" missing path", .{result.requestLine});
            return HttpRequestError.MalformedRequestLine;
        };
        Log.debug("parsed result.path", .{});

        result.version = result.requestLine[result.target.len..];
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
        PerfLog.info("HttpRequest.init\t{d}", .{duration_ns});
        return result;
    }
    pub fn deinit(self: *HttpRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.header);
        if (self.body != null) allocator.free(self.body.?);
    }

    /// Returns the Http Header Field with the specified key if found
    pub inline fn getField(self: *const HttpRequest, key: []const u8) ?HttpHeader {
        return find_field(self.rawFields, key);
    }
};

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

    pub inline fn value(self: HttpStatusCode) u16 {
        return @intFromEnum(self);
    }

    pub inline fn name(self: HttpStatusCode) []const u8 {
        return @tagName(self);
    }

    const validStatusCodeValues = blk: {
        const fields = @typeInfo(HttpStatusCode).@"enum".fields;
        var r: [fields.len]u16 = undefined;
        for (0..fields.len) |i| {
            r[i] = @as(u16, fields[i].value);
        }
        std.mem.sort(u16, &r, {}, std.sort.asc(u16));
        break :blk r;
    };
    pub inline fn validValue(v: u16) bool {
        const idx = utils.mem.binarySearch(u16, utils.mem.compareNumberAsc(u16), validStatusCodeValues[0..], v);
        return idx != null;
    }

    /// Returns the HttpStatusCode with the specified value
    /// Caller assserts that `v` is a valid HttpStatusCode
    pub inline fn fromValue(v: u16) HttpStatusCode {
        std.debug.assert(validValue(v));
        return @as(HttpStatusCode, @enumFromInt(v));
    }

    pub const HttpStatusCodeCategory = enum(u16) {
        /// Request was received, continuing process
        Informational = 100,
        /// Request was successfully received, understood, and accepted
        Successful = 200,
        /// Further action needs to be taken in order to complete the request
        Redirection = 300,
        /// Request contains bad syntax or cannot be fulfilled
        ClientError = 400,
        /// Server failed to fulfil an apparently valid request
        ServerError = 500,
    };

    pub fn category(self: HttpStatusCode) HttpStatusCodeCategory {
        const sv: u16 = self.value();
        const cv: u16 = @divFloor(sv, 100) * 100;
        return @enumFromInt(cv);
    }

    pub fn isError(self: HttpStatusCode) bool {
        const c = self.category();
        return c == .ClientError or c == .ServerError;
    }
};
pub const HttpResponse = struct {
    const versionString = "HTTP/1.1";

    statusCode: HttpStatusCode = .OK,

    headers: HttpHeaderMap,
    body: ?[]const u8 = null,
    pub fn init(allocator: std.mem.Allocator) !HttpResponse {
        const start = std.time.nanoTimestamp();
        const r = HttpResponse{
            .headers = HttpHeaderMap.init(allocator),
        };
        const duration_ns = std.time.nanoTimestamp() - start;
        PerfLog.info("HttpResponse.init\t{d}", .{duration_ns});
        return r;
    }
    pub fn deinit(self: *HttpResponse) void {
        self.headers.deinit();
        if (self.body != null) self.headers.allocator.free(self.body.?);
    }

    /// Sets the HTTP Date header to now
    pub fn setDateHeader(self: *HttpResponse) !void {
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

        try self.headers.set(key[0..], value[0..]);
    }

    /// sets the Content-Length header field to match self.body.len
    pub fn setContentLengthHeader(self: *HttpResponse) !void {
        var buf: [16]u8 = undefined;
        const contentLength: usize = blk: {
            if (self.body == null) break :blk 0;
            break :blk self.body.?.len;
        };
        const str = utils.strings.fastIntToString(@TypeOf(contentLength), contentLength, &buf);
        try self.headers.set("Content-Length", str);
    }

    fn writeHeaderFields(self: *const HttpResponse, writer: std.io.AnyWriter) !void {
        for (self.headers.all()) |header| {
            try std.fmt.format(writer, "{s}\r\n", .{header.string()});
        }
    }
    fn writeStatusLine(self: *const HttpResponse, writer: std.io.AnyWriter) !void {
        try std.fmt.format(writer, "{s} {d} {s}\r\n", .{ versionString, @intFromEnum(self.statusCode), @tagName(self.statusCode) });
    }
    pub fn send(self: *HttpResponse, stream: TCPConnection) !void {
        const start = std.time.nanoTimestamp();
        var writer = stream.anywriter();

        try self.setDateHeader();
        try self.setContentLengthHeader();
        try self.writeStatusLine(writer);
        try self.writeHeaderFields(writer);
        if (self.body != null) {
            _ = try writer.write("\r\n"[0..]);
            _ = try writer.write(self.body.?[0..]);
        }
        const duration_ns = std.time.nanoTimestamp() - start;
        PerfLog.info("HttpResponse.send\t{d}", .{duration_ns});
    }
};

// === HANDLER ===
/// Function that can handle requests. Must return false if the request cannot be handled
pub const HttpRequestHandler = struct {
    context: ?*anyopaque,
    handleFn: *const fn (?*anyopaque, *HttpContext) anyerror!bool,

    pub fn handle(self: *const HttpRequestHandler, http: *HttpContext) anyerror!bool {
        return try self.handleFn(self.context, http);
    }
};

// === Tests ===
test HttpContext {
    _ = HttpContext;
}
test HttpRequest {
    _ = HttpRequest;
}
test HttpResponse {
    _ = HttpResponse;
}
