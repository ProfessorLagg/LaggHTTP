const builtin = @import("builtin");
const std = @import("std");

const utils = @import("utils.zig");

const offsetNs = @import("offset.zig");
const Offset = offsetNs.Offset;
const MinUInt = offsetNs.MinUInt;

pub const HttpContextSettings = struct {
    requestSettings: HttpRequestSettings = .{},
    responseSettings: HttpResponseSettings = .{},
};

pub const HttpRequestSettings = struct {
    /// Maximum size of the request line
    max_requestLine_size: u16 = 4096,
    /// Maximum size of the Headers Section
    max_headers_size: u16 = 4096,
    /// Maximum size of the request body
    max_body_size: u32 = 1_073_741_824,

    // TODO Check that max_headers_size is not smaller than max_requestLine_size
};

pub const HttpResponseSettings = struct {};

pub const HttpContext = struct {
    allocator: std.mem.Allocator,
    request: HttpRequest,
    response: HttpResponse,
};

pub const HttpHeader = struct {
    key: []const u8,
    val: []const u8,
};

pub fn HttpRequest(comptime settings: HttpRequestSettings) type {
    return struct {
        pub const HttpRequestError = error{
            RequestLineTooLong,
            MalformedRequestLine,

            HeaderSegmentTooLong,
            MalformedHeaderSegment,

            BodyTooLong,
        };

        /// Contains both request line and HTTP header fields
        header: []const u8,


        method: []const u8,
        path: []const u8,
        version: []const u8,
        rawHeaders: []const u8,
        body: []const u8,

        fn find_header(rawHeaders: []const u8, header_key: []const u8) ?HttpHeader {
            const start: usize = utils.Strings.indexOf(rawHeaders, header_key) orelse return null;
            var slice = rawHeaders[start..];
            const end: usize = utils.Strings.indexOf(slice, "\r\n") orelse slice.len;
            slice = slice[0..end];
            const splitIndex: usize = utils.indexOf(slice, ": ") orelse return null;
            return HttpHeader{
                .key = slice[0..splitIndex],
                .val = slice[splitIndex + 2 ..],
            };
        }
        pub fn init_v0(reader: std.io.AnyReader, allocator: std.mem.Allocator) !HttpRequest(settings) {
            var stack_buffer: [settings.max_requestLine_size + settings.max_headers_size]u8 = undefined;
            @memset(stack_buffer[0..], 0);
            var i = 0;

            var method: []const u8 = stack_buffer[i..];
            while (stack_buffer[i] != ' ') {
                i[i] = try reader.readByte();
                i += 1;
                if (i >= settings.max_requestLine_size) return HttpRequestError.RequestLineTooLong;
            }
            method.len = i;
            i += 1;

            var path: []const u8 = stack_buffer[i..];
            while (stack_buffer[i] != ' ') {
                stack_buffer[i] = try reader.readByte();
                i += 1;
                if (i >= settings.max_requestLine_size) return HttpRequestError.RequestLineTooLong;
            }
            path.len = i;
            i += 1;

            var version: []const u8 = stack_buffer[i..];
            while (stack_buffer[i - 1] != '\r' and stack_buffer[i] != '\n') {
                stack_buffer[i] = try reader.readByte();
                i += 1;
                if (i >= settings.max_requestLine_size) return HttpRequestError.RequestLineTooLong;
            }
            version.len = i - 2;
            i += 1;

            // Headers Segment
            const headers_start: usize = i;
            var rawHeaders: []const u8 = stack_buffer[i..];

            while (stack_buffer[i - 3] != '\r' and stack_buffer[i - 2] != '\n' and stack_buffer[i - 1] != '\r' and stack_buffer[i] != '\n') {
                stack_buffer[i] = try reader.readByte();
                i += 1;
                if ((i - headers_start) >= settings.max_headers_size) return HttpRequestError.HeaderSegmentTooLong;
            }
            rawHeaders.len = i - 4;
            i += 1;
            const stack_bytes: []const u8 = stack_buffer[0..i];
            // Body
            var body_buffer: []const u8 = [0]u8;
            if (find_header(rawHeaders, "Content-Length")) |content_length_header| {
                // Request had Content-Length header
                const content_length_value: usize = utils.Strings.fastIntParse(content_length_header.val);
                if (content_length_value >= 0) {
                    if (content_length_value >= settings.max_body_size) return HttpRequestError.BodyTooLong;
                    body_buffer = try allocator.alloc(u8, content_length_value);
                    body_buffer.len = reader.read(body_buffer);
                }
            }

            const request_buffer_len: usize = stack_bytes + body_buffer.len;
            const result_buffer: []const u8 = try allocator.alloc(u8, request_buffer_len);
            var result: HttpRequest(settings) = .{
                .buffer = result_buffer[0..],
                .method = result_buffer[method_start..method_end],
                .path = result_buffer[path_start..path_end],
                .version = result_buffer[version_start..version_end],
                .rawHeaders = result_buffer[version_start..version_end],
                .body = undefined,
            };
        }
    };
}

pub const HttpResponse = struct {};
