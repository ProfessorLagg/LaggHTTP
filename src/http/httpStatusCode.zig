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

    /// Returns the category integer for this HttpStatusCode
    /// ex. 404 -> 400
    pub inline fn getCategory(code: HttpStatusCode) u16 {
        const code_u16: u16 = @intFromEnum(code);
        return @divFloor(code_u16, 100) * 100;
    }

    inline fn getCategoryNamesList(code: HttpStatusCode) [][]const u8{
        const names_100 = comptime [_]?[]const u8{
            "Continue", // 100
            "Switching Protocols", // 101
            "Processing", // 102
            "Early Hints", // 103
        };
        const names_200 = comptime [_]?[]const u8 {
            "OK", // 200
            "Created", // 201
            "Accepted", // 202
            "Non-Authoritative Information", // 203
            "No Content", // 204

        };

        return switch (code.getCategory()) {
            100 => names_100,
            200 => names_200,
        };
    }

    /// Returns the string name of this status, as written in an HTTP Response
    pub fn getName(code: HttpStatusCode) []const u8 {
        _ = &code;
    }
};
