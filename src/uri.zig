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
    MalformedAuthority,
    HostMissing,
};

/// RFC 3986 Uniform Resource Identifier (URI)
pub const URI = @This();

scheme: ?[]const u8 = null,
authority: ?[]const u8 = null,
userinfo: ?[]const u8 = null,
host: ?[]const u8 = null,
port: ?[]const u8 = null,
path: ?[]const u8 = null,
query: ?[]const u8 = null,
fragment: ?[]const u8 = null,

/// Helper function to parse the Authority sub-components. Only intended for use inside the parse function
inline fn parseAuthoritySubComponents(self: *URI) !void {
    std.debug.assert(self.authority != null);
    if (self.authority.?.len <= 1) return URIError.MalformedAuthority;

    var S = self.authority.?[0..];
    if (std.mem.indexOfScalar(u8, S, '@')) |userinfo_end| {
        self.userinfo = S[0..userinfo_end];
        S = S[userinfo_end + 1 ..];
    }
    if (std.mem.indexOfScalar(u8, S, ':')) |port_start| {
        self.port = S[port_start + 1 ..];
        S = S[0..port_start];
    }
    self.host = S[0..];
    if (self.host.?.len <= 1) return URIError.HostMissing;
}
/// Tries to slice `str` into it's component URI parts
fn parse_old(str: []const u8) URIError!URI {
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
    S = S[uri.scheme.len + 1 ..];

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

        try uri.parseAuthoritySubComponents();
    }

    S = S[@intFromBool(S[0] == '/')..];
    uri.path = S[0..0];
    while (uri.path.len < S.len) {
        const c: u8 = S[uri.path.len];
        if (URICharacterType.get(c) == .invalid) return URIError.InvalidCharacter;
        switch (c) {
            '?', '#' => break,
            else => uri.path.len += 1,
        }
    }
    S = S[uri.path.len..];

    while (S.len > 0) {
        switch (S[0]) {
            '?' => {
                // Parsing query
                S = S[@intFromBool(S[0] == '?')..];
                uri.query = S[0..0];
                il: while (uri.query.?.len < S.len) {
                    const c: u8 = S[uri.query.?.len];
                    if (URICharacterType.get(c) == .invalid) return URIError.InvalidCharacter;
                    if (c == '#') break :il;
                    uri.query.?.len += 1;
                }
                S = S[uri.query.?.len..];
            },
            '#' => {
                // Parsing fragment
                S = S[@intFromBool(S[0] == '#')..];
                uri.fragment = S[0..];
                S = S[uri.fragment.?.len..];
            },
            else => unreachable,
        }
    }

    return uri;
}

/// Tries to slice `str` into it's component URI parts
pub fn parse(str: []const u8) URIError!URI {
    for (str) |c| if (URICharacterType.get(c) == .invalid) return URIError.InvalidCharacter;

    // TODO Check for minimum URI length
    var S = str[0..];
    var uri: URI = .{};

    // Parsing scheme
    if (std.mem.indexOfScalar(u8, S, ':')) |scheme_end| {
        uri.scheme = S[0..scheme_end];
        S = S[@min(S.len - 1, scheme_end + 1)..];

        //std.log.debug("parsed scheme as \"{s}\". Remainder of S = \"{s}\"", .{ uri.scheme.?, S });
    }
    if (S.len == 0) return uri;

    // Parsing Authority
    if (S.len >= 2 and std.mem.eql(u8, "//", S[0..2])) {
        S = S[2..];
        const authority_end: usize = std.mem.indexOfScalar(u8, S, '/') orelse S.len;
        uri.authority = S[0..authority_end];
        try uri.parseAuthoritySubComponents();
        S = S[@min(S.len - 1, authority_end)..];

        //std.log.debug("parsed authority as \"{s}\". Remainder of S = \"{s}\"", .{ uri.authority.?, S });
    }
    if (S.len == 0) return uri;

    // Parsing path
    const path_end: usize = std.mem.indexOfScalar(u8, S, '?') orelse std.mem.indexOfScalar(u8, S, '#') orelse S.len;
    uri.path = std.mem.trim(u8, S[0..path_end], "/");
    S = S[@min(S.len - 1, path_end)..];

    //std.log.debug("parsed path as \"{s}\". Remainder of S = \"{s}\"", .{ uri.path.?, S });
    if (S.len == 0) return uri;

    // Parsing query
    if (std.mem.indexOfScalar(u8, S, '?')) |query_start| {
        const query_end = std.mem.indexOfScalar(u8, S, '#') orelse S.len;
        uri.query = S[query_start..query_end][1..];
        S = S[@min(S.len - 1, query_end)..];
        //std.log.debug("parsed query as \"{s}\". Remainder of S = \"{s}\"", .{ uri.query.?, S });
    }
    if (S.len == 0) return uri;

    // Parsing fragment
    if (std.mem.indexOfScalar(u8, S, '#')) |fragment_start| {
        uri.fragment = S[fragment_start..][1..];
        S = S[S.len - 1 ..];
        //std.log.debug("parsed fragment as \"{s}\". Remainder of S = \"{s}\"", .{ uri.fragment.?, S });
    }

    return uri;
}

test parse {
    const strA = "scheme://userinfo@host:1234/path/1/2/3/?query#fragment";
    const uriA: URI = try parse(strA);

    try std.testing.expect(uriA.scheme != null);
    try std.testing.expectEqualStrings("scheme", uriA.scheme.?);
    try std.testing.expect(uriA.path != null);
    try std.testing.expectEqualStrings("path/1/2/3", uriA.path.?);
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

    const strB = "scheme:path";
    const uriB: URI = try parse(strB);
    try std.testing.expectEqualStrings("scheme", uriB.scheme.?);
    try std.testing.expectEqualStrings("path", uriB.path.?);
    try std.testing.expectEqual(null, uriB.authority);
    try std.testing.expectEqual(null, uriB.host);
    try std.testing.expectEqual(null, uriB.port);
    try std.testing.expectEqual(null, uriB.query);
    try std.testing.expectEqual(null, uriB.fragment);

    const strC = "/";
    const uriC = try parse(strC);
    try std.testing.expectEqual(null, uriC.scheme);
    try std.testing.expectEqualStrings("", uriC.path.?);
    try std.testing.expectEqual(null, uriC.authority);
    try std.testing.expectEqual(null, uriC.host);
    try std.testing.expectEqual(null, uriC.port);
    try std.testing.expectEqual(null, uriC.query);
    try std.testing.expectEqual(null, uriC.fragment);

    const strD = "/index.html";
    const uriD = try parse(strD);
    try std.testing.expectEqual(null, uriD.scheme);
    try std.testing.expectEqualStrings("index.html", uriD.path.?);
    try std.testing.expectEqual(null, uriD.authority);
    try std.testing.expectEqual(null, uriD.host);
    try std.testing.expectEqual(null, uriD.port);
    try std.testing.expectEqual(null, uriD.query);
    try std.testing.expectEqual(null, uriD.fragment);
}
