const builtin = @import("builtin");
const std = @import("std");
const DateTime = @import("dateTime.zig").DateTime;

const utils = @import("utils.zig");

const native_os = builtin.target.os.tag;
const newline = switch (native_os) {
    .windows => "\r\n",
    else => "\n",
};
const static_allocator: std.mem.Allocator = switch (builtin.single_threaded) {
    true => std.heap.c_allocator,
    false => std.heap.smp_allocator,
};

// environment
var Settings: LogSettings = undefined;
var SetupRun: bool = false;

var LogDirPath: []const u8 = undefined;
var LogDir: std.fs.Dir = undefined;

var LogFile: ?std.fs.File = null;
var LogFileTimestamp: std.time.epoch.EpochDay = .{ .day = 0 };

var lock_LogFile: std.Thread.Mutex = .{};
var lock_stdout: std.Thread.Mutex = .{};

// utils

fn defaultLogDirPath(allocator: std.mem.Allocator) ![]const u8 {
    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);

    const log_dir_name = "Logs";

    const path_parts = [_][]const u8{
        exe_dir[0..],
        log_dir_name[0..],
    };
    return try std.fs.path.join(allocator, &path_parts);
}

fn getLogFileName(buf: *[14]u8) ![]const u8 {
    @memset(buf[0..], '0');
    const now = DateTime.now();
    return try std.fmt.bufPrint(buf[0..], "{d:0>4}-{d:0>2}-{d:0>2}.log", .{ now.year, now.month, now.day });
}

/// Returns a write ready file
fn ensureLogFile() !std.fs.File {
    const now: std.time.epoch.EpochDay = DateTime.nowEpochSeconds().getEpochDay();
    const create_new_logfile: bool = now.day != LogFileTimestamp.day;
    if (create_new_logfile) {
        if (LogFile != null) { // closes the current LogFile if it's open
            LogFile.?.close();
            LogFile = null;
        }
        var new_name_buf: [14]u8 = undefined;
        const new_name = try getLogFileName(&new_name_buf);
        // if (builtin.mode == .Debug) {
        //     const new_abspath = try LogDir.realpathAlloc(static_allocator, new_name);
        //     defer static_allocator.free(new_abspath);

        //     std.debug.print("log file path: \"{s}\"\n", .{new_abspath});
        // }

        LogFile = try LogDir.createFile(new_name, .{
            .read = false,
            .truncate = false,
            .exclusive = false,
            .lock = .none,
            .lock_nonblocking = false,
            // .mode = std.fs.File.OpenMode.write_only,
            .mode = std.fs.File.default_mode,
        });
    }

    if (LogFile == null) std.debug.panic("Ensuring Logfile failed", .{});
    return LogFile.?;
}

// setup
pub const LogSettings = struct {
    /// If `true` logs to standard out
    log_stdout: bool = false,

    /// If `true logs to file
    log_file: bool = true,

    /// Directory to place logfiles in.
    /// - if `null` uses `{exeDirectory}/Logs`
    /// - On windows must be WTF-8 encoded
    log_dir_path: ?[]const u8 = null,
};
/// Initializes file logging.
pub fn setup(config: LogSettings) !void {
    Settings = config;
    if (Settings.log_file) {
        if (Settings.log_dir_path == null) {
            const exeDirPath = try std.fs.selfExeDirPathAlloc(static_allocator);
            defer static_allocator.free(exeDirPath);

            const logDirName = "Logs";
            const path_parts = [_][]const u8{
                exeDirPath[0..],
                logDirName[0..],
            };
            Settings.log_dir_path = try std.fs.path.join(static_allocator, &path_parts);
        }
        LogDirPath = try utils.fs.abspath(static_allocator, Settings.log_dir_path.?);
        LogDir = try utils.fs.openMakeDirAbsolute(LogDirPath, .{ .access_sub_paths = true, .iterate = false, .no_follow = false });
        _ = try ensureLogFile();
    }

    SetupRun = true;
}

// logging
fn logInternal(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) !void {
    if (!SetupRun) return;

    const full_format = comptime @tagName(level) ++ "\t" ++ @tagName(scope) ++ "\t" ++ format ++ newline;

    const now = DateTime.now();
    var timestamp_buf: [19]u8 = undefined;
    @memset(timestamp_buf[0..], ' ');
    const timestamp_str = try std.fmt.bufPrint(timestamp_buf[0..], "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
    });

    if (Settings.log_file) {
        lock_LogFile.lock();
        const file = try ensureLogFile();
        try file.seekFromEnd(0);
        const file_writer = file.writer();
        // TODO escape whitespace
        nosuspend {
            try std.fmt.format(file_writer, "{s: >5}\t", .{timestamp_str});
            try std.fmt.format(file_writer, full_format, args);
        }
        lock_LogFile.unlock();
    }

    if (Settings.log_stdout) {
        lock_stdout.lock();
        const file = std.io.getStdOut();
        const file_writer = file.writer();
        // TODO escape whitespace
        nosuspend {
            try std.fmt.format(file_writer, "{s}\t", .{timestamp_str});
            try std.fmt.format(file_writer, full_format, args);
        }
        lock_stdout.unlock();
    }
}
pub fn log(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
    logInternal(level, scope, format, args) catch |err| std.debug.panic("could not write log: {any}{any}", .{ err, @errorReturnTrace() });
}

pub fn noopLog(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
    _ = level;
    _ = scope;
    _ = format;
    _ = args;
}
