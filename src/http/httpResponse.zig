const std = @import("std");
const utils = @import("../utils.zig");
const log = std.log.scoped(.HttpResponse);

pub const HttpResponse = struct {
    pub const StatusCode = enum(u16) {
        // Informational
        Continue = 100,
        SwitchingProtocols = 101,

        // Success
        OK = 200,
        Created = 201,
        Accepted = 202,
        NonAuthoritativeInformation = 203,
        NoContent = 204,
        ResetContent = 205,
        PartialContent = 206,

        // Redirection
        MultipleChoices = 300,
        MovedPermanently = 301,
        Found = 302,
        SeeOther = 303,
        NotModified = 304,
        UseProxy = 305,
        TemporaryRedirect = 307,
        PermanentRedirect = 308,

        // Client Error
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
        ContentTooLarge = 413,
        URITooLong = 414,
        UnsupportedMediaType = 415,
        RangeNotSatisfiable = 416,
        ExpectationFailed = 417,
        MisdirectedRequest = 421,
        UnprocessableContent = 422,
        UpgradeRequired = 426,

        // Server Error
        InternalServerError = 500,
        NotImplemented = 501,
        BadGateway = 502,
        ServiceUnavailable = 503,
        GatewayTimeout = 504,
        HTTPVersionNotSupported = 505,
    };

    /// Map type used for Headers
    const TMap = std.StringArrayHashMap([]const u8);

    /// List type used for the body segments
    const TList = std.ArrayList([]const u8);

    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: TMap,
    bodySegments: TList,

    pub fn init(allocator: std.mem.Allocator) HttpResponse {
        return HttpResponse{
            .allocator = allocator,
            .status = .OK,
            .headers = TMap.init(allocator),
            .body = TList.init(allocator),
        };
    }

    pub fn deinit(self: *HttpResponse) void {
        self.headers.deinit();
        if (self.body != null) {
            self.allocator.free(self.body);
        }
    }

    pub fn addHeader(self: *HttpResponse, key: []const u8, value: []const u8) !void {
        try self.headers.put(key, value);
    }

    /// Appends bytes to the body of the response.
    pub fn writeBody(self: *HttpResponse, bytes: []const u8) !void {
        try self.bodySegments.append(bytes);
    }
};
