const builtin = @import("builtin");
const std = @import("std");

const URICharacterType = enum {
    reserved,
    subdelim,
    unreserved,
    escape,
    invalid,

    const CharTypeLookup: [256]URICharacterType = blk: {
        var result: [256]URICharacterType = undefined;
        @memset(result[0..], URICharacterType.invalid);

        const reserved_chars = [_]u8{ ':', '/', '?', '#', '[', ']', '@' };
        for (reserved_chars) |c| result[c] = .reserved;

        const subdelim_chars = [_]u8{ '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '=' };
        for (subdelim_chars) |c| result[c] = .subdelim;

        for ('0'..'9' + 1) |c| result[c] = .unreserved; // Numbers
        for ('A'..'Z' + 1) |c| result[c] = .unreserved; // Uppercase
        for ('a'..'z' + 1) |c| result[c] = .unreserved; // Lowercase
        for ("-._~"[0..]) |c| result[c] = .unreserved; // Special

        result['%'] = .escape;
        break :blk result;
    };

    /// Returns the URI character type for the input character
    pub inline fn get(c: u8) URICharacterType {
        return CharTypeLookup[c];
    }
};

pub const URIError = error{
    InvalidCharacter,
    SchemeMissing,
    PathMissing,
    MalformedAuthority,
};

/// RFC 3986 Uniform Resource Identifier (URI)
pub const URI = @This();

scheme: []const u8 = undefined,
authority: ?[]const u8 = null,
userinfo: ?[]const u8 = null,
host: ?[]const u8 = null,
port: ?[]const u8 = null,
path: []const u8 = undefined,
query: ?[]const u8 = undefined,
fragment: ?[]const u8 = undefined,

/// Tries to slice `str` into it's component URI parts
pub fn parse(str: []const u8) URIError!URI {
    // TODO Check for minimum URI length
    var S = str[0..];
    var uri: URI = .{};

    // Parsing scheme
    uri.scheme = str[0..0];
    while (S[uri.scheme.len] != ':') {
        if (uri.scheme.len == S.len) return URIError.SchemeMissing;
        if (URICharacterType.get(S[uri.scheme.len]) == .invalid) return URIError.InvalidCharacter;
        uri.scheme.len += 1;
    }
    S = S[uri.scheme.len + 1..];
    std.log.warn("parsed scheme as '{s}'. Remaning of S is '{s}'", .{ uri.scheme, S });
    // Parsing Authority
    if (S[0] == '/' and S[1] == '/') {
        S = S[2..];
        uri.authority = S[0..0];
        while (S[uri.authority.?.len] != '/') {
            if (uri.authority.?.len == S.len) return URIError.MalformedAuthority;
            if (URICharacterType.get(S[uri.authority.?.len]) == .invalid) return URIError.InvalidCharacter;
            uri.authority.?.len += 1;
        }
        S = S[uri.authority.?.len..];
        std.log.warn("parsed authority as '{s}'. Remaning of S is '{s}'", .{ uri.scheme, S });
        // TODO Parse Authority sub-components
    }

    uri.path = S[0..0];
    var tptr: *[]const u8 = &uri.path;
    while (tptr.len < S.len) {
        const c: u8 = S[tptr.len];
        if (URICharacterType.get(c) == .invalid) return URIError.InvalidCharacter;
        switch (c) {
            '@' => {
                // the path is over and i've hit the query part
                std.debug.assert(tptr == &uri.path);
                S = S[tptr.len + 1 ..];
                uri.query = S[0..0];
                tptr = &uri.query.?;
            },
            '#' => {
                std.debug.assert( //
                    (uri.query == null and tptr == &uri.path) // if query is null, tptr should be path
                    or (uri.query != null and tptr == &uri.query.?) // if query is not null, tptr should be query
                );

                S = S[tptr.len + 1 ..];
                uri.fragment = S[0..0];
                tptr = &uri.fragment.?;
            },

            else => tptr.len += 1,
        }
    }

    return uri;
}

test parse {
    const uri_strA = "scheme://userinfo@host:1234/path?query#fragment";
    const uriA: URI = try parse(uri_strA);
    try std.testing.expectEqualStrings("scheme", uriA.scheme);
    try std.testing.expectEqualStrings("path", uriA.path);

    try std.testing.expect(uriA.authority != null);
    try std.testing.expectEqualStrings("userinfo@host:1234", uriA.authority.?);
    try std.testing.expect(uriA.userinfo != null);
    try std.testing.expectEqualStrings("userinfo", uriA.userinfo.?);
    try std.testing.expect(uriA.host != null);
    try std.testing.expectEqualStrings("host", uriA.host.?);
    try std.testing.expect(uriA.port != null);
    try std.testing.expectEqualStrings("1234", uriA.port.?);

    try std.testing.expect(uriA.query != null);
    try std.testing.expectEqualStrings("query", uriA.query.?);
    try std.testing.expect(uriA.fragment != null);
    try std.testing.expectEqualStrings("fragment", uriA.fragment.?);

    const uri_strB = "scheme:path";
    const uriB: URI = try parse(uri_strB);
    try std.testing.expectEqualStrings("scheme", uriB.scheme);
    try std.testing.expectEqualStrings("path", uriB.path);
    try std.testing.expectEqual(null, uriB.authority);
    try std.testing.expectEqual(null, uriB.host);
    try std.testing.expectEqual(null, uriB.port);
    try std.testing.expectEqual(null, uriB.query);
    try std.testing.expectEqual(null, uriB.fragment);
}
