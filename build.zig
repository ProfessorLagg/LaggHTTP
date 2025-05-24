const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ===== MODULES =====
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const debugger_mod = b.createModule(.{
        .root_source_file = b.path("src/_debugger.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    debugger_mod.addImport("LaggHTTP", lib_mod);

    // ===== ARTIFACTS =====
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "LaggHTTP",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    const debugger = b.addExecutable(.{
        .name = "LaggHTTP.Debugger",
        .root_module = debugger_mod,
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
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
