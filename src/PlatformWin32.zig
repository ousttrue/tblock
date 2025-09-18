const std = @import("std");
const Input = @import("input.zig").Input;

input: std.fs.File,
output: std.fs.File,
counter: u32 = 0,

pub fn setupStdout(stdout: std.fs.File) bool {
    return enableVirtualTerminalProcessing(stdout.handle);
}

fn enableVirtualTerminalProcessing(stdout_handle: std.os.windows.HANDLE) bool {
    var mode: u32 = undefined;
    if (std.os.windows.kernel32.GetConsoleMode(stdout_handle, &mode) == std.os.windows.FALSE) {
        return false;
    }
    if (std.os.windows.kernel32.SetConsoleMode(
        stdout_handle,
        mode | std.os.windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING,
    ) == std.os.windows.FALSE) {
        return false;
    }
    return true;
}

pub fn init(allocator: std.mem.Allocator, input: std.fs.File, output: std.fs.File) !*@This() {
    const self = try allocator.create(@This());

    self.* = .{
        .input = input,
        .output = output,
    };

    return self;
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    allocator.destroy(self);
}

pub fn blockInput(self: *@This(), timeout: i32) !Input {
    _ = timeout;
    defer self.counter += 1;

    if (self.counter == 0) {
        var csbi: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        _ = std.os.windows.kernel32.GetConsoleScreenBufferInfo(self.output.handle, &csbi);
        return .{ .resize = .{
            .rows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1,
            .cols = csbi.srWindow.Right - csbi.srWindow.Left + 1,
        } };
    } else {
        var records: [1]INPUT_RECORD = undefined;
        var cNumRead: u32 = undefined;

        while (true) {
            if (ReadConsoleInputW(self.input.handle, &records, records.len, &cNumRead) == 0) {
                return error.ReadConsoleInputW;
            }
            for (records) |r| {
                switch (r.EventType) {
                    .KEY_EVENT => {
                        if (r.Event.KeyEvent.bKeyDown == 0) {
                            continue;
                        }
                        if (r.Event.KeyEvent.uChar.AsciiChar == 13) {
                            continue;
                        }
                        return .{ .key = .{ .char = r.Event.KeyEvent.uChar.AsciiChar } };
                    },
                    .MOUSE_EVENT => {},
                    .WINDOW_BUFFER_SIZE_EVENT => {
                        return .{ .resize = .{
                            .rows = r.Event.WindowBufferSizeEvent.dwSize.Y,
                            .cols = r.Event.WindowBufferSizeEvent.dwSize.X,
                        } };
                    },
                    .MENU_EVENT => {},
                    .FOCUS_EVENT => {},
                }
            }
        }
    }

    unreachable;
}

pub extern "kernel32" fn ReadConsoleInputW(
    hConsoleInput: ?std.os.windows.HANDLE,
    lpBuffer: [*]INPUT_RECORD,
    nLength: u32,
    lpNumberOfEventsRead: ?*u32,
) callconv(.winapi) std.os.windows.BOOL;

pub const COORD = extern struct {
    X: i16,
    Y: i16,
};

pub const SMALL_RECT = extern struct {
    Left: i16,
    Top: i16,
    Right: i16,
    Bottom: i16,
};

pub const KEY_EVENT_RECORD = extern struct {
    bKeyDown: std.os.windows.BOOL,
    wRepeatCount: u16,
    wVirtualKeyCode: u16,
    wVirtualScanCode: u16,
    uChar: extern union {
        UnicodeChar: u16,
        AsciiChar: std.os.windows.CHAR,
    },
    dwControlKeyState: u32,
};

pub const MOUSE_EVENT_RECORD = extern struct {
    dwMousePosition: COORD,
    dwButtonState: u32,
    dwControlKeyState: u32,
    dwEventFlags: u32,
};

pub const WINDOW_BUFFER_SIZE_RECORD = extern struct {
    dwSize: COORD,
};

pub const MENU_EVENT_RECORD = extern struct {
    dwCommandId: u32,
};

pub const FOCUS_EVENT_RECORD = extern struct {
    bSetFocus: std.os.windows.BOOL,
};

pub const EVENT_TYPE = enum(u16) {
    KEY_EVENT = 0x0001,
    MOUSE_EVENT = 0x0002,
    WINDOW_BUFFER_SIZE_EVENT = 0x0004,
    MENU_EVENT = 0x0008,
    FOCUS_EVENT = 0x0010,
};

pub const INPUT_RECORD = extern struct {
    EventType: EVENT_TYPE,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        MouseEvent: MOUSE_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MenuEvent: MENU_EVENT_RECORD,
        FocusEvent: FOCUS_EVENT_RECORD,
    },
};
