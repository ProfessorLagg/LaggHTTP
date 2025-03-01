const std = @import("std");
pub const HttpStatusCode = enum(u16) {
    // Informational
    Continue = 100,
    SwitchingProtocols = 101,
    /// Deprecated
    Processing = 102,
    EarlyHints = 103,

    // Success
    OK = 200,
    Created = 201,
    Accepted = 202,
    NonAuthoritativeInformation = 203,
    NoContent = 204,
    ResetContent = 205,
    PartialContent = 206,
    MultiStatus = 207,
    AlreadyReported = 208,

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
    ImATeapot = 418,
    MisdirectedRequest = 421,
    UnprocessableContent = 422,
    Locked = 423,
    FailedDependency = 424,
    TooEarly = 425,
    UpgradeRequired = 426,
    PreconditionRequired = 428,
    TooManyRequests = 429,
    RequestHeaderFieldsTooLarge = 431,
    UnavailableForLegalReasons = 451,

    // Server Error
    InternalServerError = 500,
    NotImplemented = 501,
    BadGateway = 502,
    ServiceUnavailable = 503,
    GatewayTimeout = 504,
    HTTPVersionNotSupported = 505,
    VariantAlsoNegotiates = 506,
    InsufficientStorage = 507,
    LoopDetected = 508,
    NotExtended = 510,
    NetworkAuthenticationRequired = 511,

    /// Returns the category integer for this HttpStatusCode
    /// ex. 404 -> 400
    pub inline fn getCategory(code: HttpStatusCode) u16 {
        const code_u16: u16 = @intFromEnum(code);
        return @divFloor(code_u16, 100) * 100;
    }

    const CodeNameInfo = struct {
        code: HttpStatusCode,
        name: []const u8,
    };
    inline fn makeCategoryNamesList(comptime names: []const CodeNameInfo) [99]?[]const u8 {
        var result: [99]?[]const u8 = undefined;
        inline for (0..result.len) |i| {
            result[i] = null;
        }
        inline for (names) |name| {
            const cat = getCategory(name.code);
            const i: u16 = @as(u16, @intFromEnum(name.code)) - cat;
            result[i] = name.name;
        }
        return result;
    }

    inline fn getCategoryNamesList(code: HttpStatusCode) []const []const u8 {
        const names_100 = comptime makeCategoryNamesList([_]CodeNameInfo{
            .{ .Continue, "Continue" },
            .{ .Switching, "Switching Protocols" },
            .{ .Processing, "Processing" },
            .{ .EarlyHints, "Early Hints" },
        });
        const names_200 = comptime makeCategoryNamesList([_]CodeNameInfo{
            .{ .OK, "OK" },
            .{ .Created, "Created" },
            .{ .Accepted, "Accepted" },
            .{ .NonAuthoritativeInformation, "Non-Authoritative Information" },
            .{ .NoContent, "No Content" },
            .{ .ResetContent, "Reset Content" },
            .{ .PartialContent, "Partial Content" },
            .{ .MultiStatus, "Multi-Status" },
            .{ .AlreadyReported, "Already Reported" },
        });
        const names_300 = comptime makeCategoryNamesList([_]CodeNameInfo{
            .{ .MultipleChoices, "Multiple Choices" },
            .{ .MovedPermanently, "Moved Permanently" },
            .{ .Found, "Found" },
            .{ .SeeOther, "See Other" },
            .{ .NotModified, "Not Modified" },
            .{ .TemporaryRedirect, "Temporary Redirect" },
            .{ .PermanentRedirect, "Permanent Redirect" },
        });
        const names_400 = comptime makeCategoryNamesList([_]CodeNameInfo{
            .{ .BadRequest, "Bad Request" },
            .{ .Unauthorized, "Unauthorized" },
            .{ .PaymentRequired, "Payment Required" },
            .{ .Forbidden, "Forbidden" },
            .{ .NotFound, "Not Found" },
            .{ .MethodNotAllowed, "Method Not Allowed" },
            .{ .NotAcceptable, "Not Acceptable" },
            .{ .ProxyAuthenticationRequired, "Proxy Authentication Required" },
            .{ .RequestTimeout, "Request Timeout" },
            .{ .Conflict, "Conflict" },
            .{ .Gone, "Gone" },
            .{ .LengthRequired, "Length Required" },
            .{ .PreconditionFailed, "Precondition Failed" },
            .{ .ContentTooLarge, "Content Too Large" },
            .{ .URITooLong, "URI Too Long" },
            .{ .UnsupportedMediaType, "Unsupported Media Type" },
            .{ .RangeNotSatisfiable, "Range Not Satisfiable" },
            .{ .ExpectationFailed, "Expectation Failed" },
            .{ .ImATeapot, "I'm a teapot" },
            .{ .MisdirectedRequest, "Misdirected Request" },
            .{ .UnprocessableContent, "Unprocessable Content" },
            .{ .Locked, "Locked" },
            .{ .FailedDependency, "Failed Dependency" },
            .{ .TooEarly, "Too Early" },
            .{ .UpgradeRequired, "Upgrade Required" },
            .{ .PreconditionRequired, "Precondition Required" },
            .{ .TooManyRequests, "Too Many Requests" },
            .{ .RequestHeaderFieldsTooLarge, "Request Header Fields Too Large" },
            .{ .UnavailableForLegalReasons, "Unavailable For Legal Reasons" },
        });
        const names_500 = comptime makeCategoryNamesList([_]CodeNameInfo{
            .{ .InternalServerError, "Internal Server Error" },
            .{ .NotImplemented, "Not Implemented" },
            .{ .BadGateway, "Bad Gateway" },
            .{ .ServiceUnavailable, "Service Unavailable" },
            .{ .GatewayTimeout, "Gateway Timeout" },
            .{ .HTTPVersionNotSupported, "HTTP Version Not Supported" },
            .{ .VariantAlsoNegotiates, "Variant Also Negotiates" },
            .{ .InsufficientStorage, "Insufficient Storage" },
            .{ .LoopDetected, "Loop Detected" },
            .{ .NotExtended, "Not Extended" },
            .{ .NetworkAuthenticationRequired, "Network Authentication Required" },
        });
        return switch (code.getCategory()) {
            100 => names_100,
            200 => names_200,
            300 => names_300,
            400 => names_400,
            500 => names_500,
            else => @panic("Invalid Status Code"),
        };
    }

    /// Returns the string name of this status, as written in an HTTP Response
    pub fn getName(code: HttpStatusCode) []const u8 {
        const namelist = getCategoryNamesList(code);
        const category = getCategory(code);
        const index = @as(u16, @intFromEnum(u16)) - category;
        std.debug.assert(namelist[index] != null);
        return namelist[index].?;
    }

    pub fn write(code: HttpStatusCode, writer: std.io.AnyWriter) !void {
        const name = code.getName();
        const int: u16 = @intFromEnum(code);
        try std.fmt.format(writer, "{d} {s}",.{
            name,
            int
        });
    }
};
