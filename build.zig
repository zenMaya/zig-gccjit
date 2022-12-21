const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addExecutable("zig-gccjit", "src/gccjit.zig");
    lib.linkLibC();
    lib.linkSystemLibrary("gccjit");
    lib.setBuildMode(mode);
    lib.install();

    const tests = b.addTest("src/test.zig");
    tests.linkLibC();
    tests.linkSystemLibrary("gccjit");
    tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);
}
