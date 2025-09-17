const std = @import("std");

pub fn setupStdout(stdout: std.fs.File) bool {
    _ = stdout;
    return true;
}
