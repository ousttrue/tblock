const std = @import("std");
const tblock = @import("tblock");

pub fn main() !void {
    var buf: [128]u8 = undefined;
    const stdout = std.fs.File.stdout();
    var stdout_writer = stdout.writer(&buf);
    const stdout_interface = &stdout_writer.interface;

    if (std.fs.File.stdin().isTty()) {
        _ = try stdout_interface.write("tty\n");

        if (enable_virtual_terminal_processing(stdout.handle)) {
            _ = try stdout_interface.write("\x1b[31mRED \x1b[32mGREEN \x1b[34mBLUE\x1b[0m\n");
        } else {
            _ = try stdout_interface.write("Failed to enable virtual terminal\n");
        }
    } else {
        _ = try stdout_interface.write("not\n");
    }

    try stdout_interface.flush();
}

fn enable_virtual_terminal_processing(handle: std.os.windows.HANDLE) bool {
    var mode: u32 = undefined;
    if (std.os.windows.kernel32.GetConsoleMode(handle, &mode) == std.os.windows.FALSE) {
        return false;
    }
    if (std.os.windows.kernel32.SetConsoleMode(
        handle,
        mode | std.os.windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING,
    ) == std.os.windows.FALSE) {
        return false;
    }
    return true;
}
