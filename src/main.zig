const std = @import("std");
const tblock = @import("tblock");
const builtin = @import("builtin");
const Platform = if (builtin.os.tag == .windows)
    @import("PlatformWin32.zig")
else
    @import("PlatformLinux.zig");

const App = struct {
    writer: std.fs.File.Writer,
    is_running: bool = true,
    buf: [128]u8 = undefined,

    fn init(allocator: std.mem.Allocator, output: std.fs.File) !*@This() {
        var self = try allocator.create(@This());
        self.* = .{
            .writer = output.writer(&self.buf),
        };

        return self;
    }

    fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    fn write(self: *@This(), str: []const u8) !void {
        _ = try self.writer.interface.write(str);
        try self.writer.interface.flush();
    }

    fn print(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
        try self.writer.interface.print(fmt, args);
        try self.writer.interface.flush();
    }

    fn dispatch(self: *@This(), ch: u8) !void {
        if (ch == 'q') {
            self.is_running = false;
        }
        try self.print("{}\n", .{ch});
    }
};

pub fn main() !void {
    //
    // initialize
    //
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const stdin = std.fs.File.stdin();
    const stdout = std.fs.File.stdout();

    if (stdin.isTty()) {
        if (Platform.setupStdout(stdout)) {
            //
        } else {
            _ = try stdout.write("Failed to enable virtual terminal\n");
            return;
        }
    } else {
        _ = try stdout.write("not tty\n");
        return;
    }

    const allocator = gpa.allocator();

    const platform = try Platform.init(allocator, stdin);
    defer platform.deinit(allocator);

    var app = try App.init(allocator, stdout);
    defer app.deinit(allocator);

    //
    // main loop
    //
    while (app.is_running) {
        // render
        try app.write("\x1b[31mRED \x1b[32mGREEN \x1b[34mBLUE\x1b[0m\n");

        // input
        const i = try platform.blockInput(-1);
        try app.dispatch(i);
    }
}
