const std = @import("std");
const log = std.log.scoped(.HttpRequest);

pub const HttpRequest = struct {
    const TSelf = @This();

    allocator: std.mem.Allocator,
    raw: []const u8,

    method: []const u8,
    route: []const u8,
    version: []const u8,

    body: []const u8,

    inline fn parseFirstLine(self: *TSelf, line: []const u8) void {
        var first_line_split = std.mem.splitScalar(u8, line, ' ');

        var val: ?[]const u8 = first_line_split.next();
        if (val == null) {
            log.err("Invalid request: could not find method field in line: \"{s}\"", .{line});
            self.method = self.raw[0..0];
        } else {
            self.method = val.?;
        }

        val = first_line_split.next();
        if (val == null) {
            log.err("Invalid request: could not find route field in line: \"{s}\"", .{line});
            self.route = self.raw[0..0];
        } else {
            self.route = val.?;
        }

        val = first_line_split.next();
        if (val == null) {
            log.err("Invalid request: could not find version field in line: \"{s}\"", .{line});
            self.version = self.raw[0..0];
        } else {
            self.version = val.?;
        }
    }

    /// Parses the raw bytes
    fn parse(self: *TSelf) void {
        // minimum |Method Route Version| string length
        std.debug.assert(self.raw.len > 14);

        var split_reader = std.mem.split(u8, self.raw, "\r\n");
        self.parseFirstLine(split_reader.first());

        var line_index: usize = 1;
        while (split_reader.next()) |line| : (line_index += 1) {
            log.debug("line {d}: \"{}\"", .{ line_index, std.zig.fmtEscapes(line) });
            // parsing headers
            // TODO parse header
            _ = &line;
        }

        self.body = split_reader.rest();
    }

    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) !TSelf {
        var r = TSelf{
            .allocator = allocator,
            .raw = undefined,
            .method = undefined,
            .route = undefined,
            .version = undefined,
            .body = undefined,
        };

        const raw: []u8 = try allocator.alloc(u8, bytes.len);
        @memcpy(raw, bytes);
        r.raw = raw;
        r.parse();

        return r;
    }

    pub fn deinit(self: *TSelf) void {
        self.allocator.free(self.raw);
    }

    pub fn format(
        self: TSelf,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        try std.fmt.format(out_stream, "[{s}] {s}:{s}", .{self.version, self.method, self.route});
        _ = &options;
    }
};
