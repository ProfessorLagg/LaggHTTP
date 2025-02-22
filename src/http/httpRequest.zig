const std = @import("std");
const utils = @import("../utils.zig");
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
            }

            // Break
            if (line.len == 0) break;

            // TODO parse headers
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

    pub fn initReader(allocator: std.mem.Allocator, reader: std.io.AnyReader) !TSelf {
        const buf_size: comptime_int = 65536;
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
        const headers_string = "WiP"; // TODO
        try std.fmt.format(out_stream, "verson: {s}\nmethod: {s}\nroute: {s}\nheaders: {s}\nbody: {}", .{ self.version, self.method, self.route, headers_string, std.zig.fmtEscapes(self.body) });
        _ = &options;
    }
};
