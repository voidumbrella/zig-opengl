const glfw = @import("libs/mach-glfw/build.zig");

const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("raytracer", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addIncludeDir("libs");
    exe.addPackagePath("gl", "libs/zgl/zgl.zig");
    exe.addPackagePath("glfw", "libs/mach-glfw/src/main.zig");
    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("assimp");
    glfw.link(b, exe, .{});

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
