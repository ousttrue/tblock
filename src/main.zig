const std = @import("std");
const tblock = @import("tblock");
const builtin = @import("builtin");
const Platform = if (builtin.os.tag == .windows)
    @import("PlatformWin32.zig")
else
    @import("PlatformLinux.zig");

pub fn main() !void {
    var buf: [128]u8 = undefined;
    const stdout = std.fs.File.stdout();
    var stdout_writer = stdout.writer(&buf);
    const stdout_interface = &stdout_writer.interface;

    if (std.fs.File.stdin().isTty()) {
        _ = try stdout_interface.write("is tty\n");
        if (Platform.setupStdout(stdout)) {
            _ = try stdout_interface.write("\x1b[31mRED \x1b[32mGREEN \x1b[34mBLUE\x1b[0m\n");
        } else {
            _ = try stdout_interface.write("Failed to enable virtual terminal\n");
        }
    } else {
        _ = try stdout_interface.write("not tty\n");
    }
    try stdout_interface.flush();
}
