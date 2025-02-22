const std = @import("std");
const utils = @import("../utils.zig");
const log = std.log.scoped(.HttpRequest);

pub const HttpRequest = struct {
    const TSelf = @This();

    /// Map type used for Headers
    const TMap = std.StringArrayHashMap([]const u8);

    allocator: std.mem.Allocator,
    raw: []const u8,

    method: []const u8,
    route: []const u8,
    version: []const u8,
    body: []const u8,

    headers: TMap,

    inline fn parseFirstLine(self: *TSelf, line: []const u8) void {
        log.debug("parseFirstLine(self: {*}, line: \"{}\")", .{ self, std.zig.fmtEscapes(line) });
        var first_line_split = std.mem.splitScalar(u8, line, ' ');

        var val: ?[]const u8 = first_line_split.next();
        if (val == null) {
            log.warn("Invalid request. Could not find method field in line: \"{}\"", .{std.zig.fmtEscapes(line)});
            self.method = self.raw[0..0];
        } else {
            self.method = val.?;
        }

        val = first_line_split.next();
        if (val == null) {
            log.warn("Invalid request. Could not find route field in line: \"{}\"", .{std.zig.fmtEscapes(line)});
            self.route = self.raw[0..0];
        } else {
            self.route = val.?;
        }

        val = first_line_split.next();
        if (val == null) {
            log.err("Invalid request. Could not find version field in line: \"{}\"", .{std.zig.fmtEscapes(line)});
            self.version = self.raw[0..0];
        } else {
            self.version = val.?;
        }
    }

    /// Parses the raw bytes
    fn parse(self: *TSelf) void {
        // minimum |Method Route Version| string length

        var split_reader = std.mem.split(u8, self.raw, "\r\n");

        var line_index: usize = 0;
        while (split_reader.next()) |line| : (line_index += 1) {
            log.debug("line {d}: \"{}\"", .{ line_index, std.zig.fmtEscapes(line) });
            if (line_index == 0) {
                std.debug.assert(line.len > 14);
                self.parseFirstLine(line);
                continue;
            }

            // Break
            if (line.len == 0) break;

            // TODO parse header line
            var split_index: usize = 0;
            while (line[split_index] != ':') {
                std.debug.assert(split_index < line.len);
                split_index += 1;
            }
            const keystr: []const u8 = line[0..split_index];
            const valstr: []const u8 = line[(split_index + 2)..];
            self.headers.put(keystr, valstr) catch |err| {
                log.err("Failed to put header. key = \"{s}\", val = \"{s}\", err = \"{}\"", .{ keystr, valstr, err });
            };
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

            .headers = TMap.init(allocator),
        };

        const raw: []u8 = try allocator.alloc(u8, bytes.len);
        @memcpy(raw, bytes);
        r.raw = raw;

        r.parse();

        return r;
    }

    pub fn initReader(allocator: std.mem.Allocator, reader: std.io.AnyReader) !TSelf {
        const buf_size: comptime_int = 4096 * 16;
        const buf: []u8 = try allocator.alloc(u8, buf_size);
        const read_len: usize = try reader.read(buf);
        const raw = buf[0..read_len];

        return TSelf.init(allocator, raw);
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
        // try std.fmt.format(out_stream, "verson: {s}\nmethod: {s}\nroute: {s}\nheaders: {}\nbody: {}", .{ self.version, self.method, self.route, self.headers, std.zig.fmtEscapes(self.body) });
        try std.fmt.format(out_stream, "verson: {s}\nmethod: {s}\nroute: {s}", .{ self.version, self.method, self.route });

        const header_keys = self.headers.keys();
        const header_vals = self.headers.values();
        const header_count: usize = @min(header_keys.len, header_vals.len);
        for (0..header_count) |i| {
            try std.fmt.format(out_stream, "\n{s}: {s}", .{ header_keys[i], header_vals[i] });
        }
        try std.fmt.format(out_stream, "\nbody: {}", .{std.zig.fmtEscapes(self.body)});
        _ = &options;
    }
};
