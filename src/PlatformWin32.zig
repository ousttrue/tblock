const std = @import("std");

pub fn setupStdout(stdout: std.fs.File) bool {
    return enable_virtual_terminal_processing(stdout.handle);
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
