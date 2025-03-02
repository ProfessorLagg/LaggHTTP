const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

const FilePaths = struct {
    pub const rootPath = "src/root.zig";
    pub const debuggerPath = "src/debugger.zig";

    pub const testPaths = [_][]const u8{ // NO FOLD
        rootPath,
        "src/http/httpServer.zig",
        "src/utils.zig",
    };

    pub fn addTestStep(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *Step {
        const test_step: *std.Build.Step = b.step("test", "Run unit tests");
        for (testPaths) |path| {
            const unit_tests = b.addTest(.{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
            });
            const run_unit_tests = b.addRunArtifact(unit_tests);
            test_step.dependOn(&run_unit_tests.step);
        }
        return test_step;
    }
};

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "LaggHTTP",
        .root_source_file = b.path(FilePaths.rootPath),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const debugger_exe = b.addExecutable(.{
        .name = "debugger",
        .root_source_file = b.path(FilePaths.debuggerPath),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
        .link_libc = false,
    });
    b.installArtifact(debugger_exe);

    const run_debugger = b.addRunArtifact(debugger_exe);
    run_debugger.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_debugger.step);

    const test_step = FilePaths.addTestStep(b, target, optimize);
    _ = &test_step;
}
