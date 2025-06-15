const builtin = @import("builtin");
const std = @import("std");

/// This is low-level implementation details of the build system, not meant to be called by users' build scripts.
/// Even in the build system itself it is a code smell to call this function.
fn pathFromInstall(b: *std.Build, sub_path: []const u8) []u8 {
    return b.pathResolve(&.{ b.install_path, sub_path });
}

fn copy_dir_to_output(b: *std.Build, src_path: []const u8, dst_path: []const u8) !void {
    const local_utils = struct {
        pub fn copyFile(s_dir: std.fs.Dir, s_path: []const u8, d_dir: std.fs.Dir, d_path: []const u8) !void {
            try s_dir.copyFile(s_path, d_dir, d_path, .{});
            const d_file: std.fs.File = try d_dir.openFile(d_path, .{ .mode = .write_only });
            const s_stat: std.fs.Dir.Stat = try s_dir.statFile(s_path);
            try d_file.updateTimes(s_stat.atime, s_stat.mtime);
        }

        pub fn openMakeDirAbsolute(absolute_path: []const u8, flags: std.fs.Dir.OpenOptions) !std.fs.Dir {
            return std.fs.openDirAbsolute(absolute_path, flags) catch |err| blk: {
                if (err == error.FileNotFound) {
                    try std.fs.makeDirAbsolute(absolute_path);
                    break :blk try std.fs.openDirAbsolute(absolute_path, flags);
                }
                break :blk err;
            };
        }
    };

    const src_abspath = b.pathFromRoot(src_path);
    var src_dir: std.fs.Dir = try std.fs.openDirAbsolute(src_abspath, .{ .iterate = true });
    const install_dir: std.fs.Dir = try local_utils.openMakeDirAbsolute(b.install_path, .{});
    var dst_dir: std.fs.Dir = try install_dir.makeOpenPath(dst_path, .{});

    var walker = try src_dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                try local_utils.copyFile(entry.dir, entry.basename, dst_dir, entry.path);
            },
            .directory => {
                dst_dir.makeDir(entry.path) catch |err| switch (err) {
                    error.PathAlreadyExists => {},
                    else => return err,
                };
            },
            else => return error.UnexpectedEntryKind,
        }
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = b.standardOptimizeOption(.{});
    const single_threaded = false;
    // const use_llvm = true;
    // const use_lld = true;

    // ===== MODULES =====
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const debugger_mod = b.createModule(.{
        .root_source_file = b.path("src/_debugger.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
        .link_libc = true,
    });
    debugger_mod.addImport("LaggHTTP", lib_mod);

    // ===== ARTIFACTS =====
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "LaggHTTP",
        .root_module = lib_mod,
        // .use_llvm = use_llvm,
        // .use_lld = use_lld,
    });

    b.installArtifact(lib);

    const debugger = b.addExecutable(.{
        .name = "LaggHTTP.Debugger",
        .root_module = debugger_mod,
        // .use_llvm = use_llvm,
        // .use_lld = use_lld,
    });
    b.installArtifact(debugger);

    // ===== RUN =====
    const run_cmd = b.addRunArtifact(debugger);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // ===== TESTS =====
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
        .test_runner = .{ .path = b.path("src/test_runner.zig"), .mode = .simple },
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // ===== TestData =====
    if (optimize == .Debug) {
        copy_dir_to_output(b, "src/testdata/wwwroot", "bin/wwwroot") catch |err| std.debug.panic("{any}{any}", .{ err, @errorReturnTrace() });
    }
}
