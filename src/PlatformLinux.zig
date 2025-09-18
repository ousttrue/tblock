const std = @import("std");

epoll_fd: i32,
events: [8]std.os.linux.epoll_event = undefined,
orig_termios: std.os.linux.termios = undefined,

pub fn setupStdout(stdout: std.fs.File) bool {
    _ = stdout;
    return true;
}

pub fn init(allocator: std.mem.Allocator, input: std.fs.File) !*@This() {
    const self = try allocator.create(@This());

    // rawmode
    _ = std.os.linux.tcgetattr(input.handle, &self.orig_termios);
    var raw: std.os.linux.termios = self.orig_termios;
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    _ = std.os.linux.tcsetattr(input.handle, .FLUSH, &raw);

    // epoll
    self.epoll_fd = @intCast(std.os.linux.epoll_create1(std.os.linux.EPOLL.CLOEXEC));
    var read_event = std.os.linux.epoll_event{
        .events = std.os.linux.EPOLL.IN,
        .data = std.os.linux.epoll_data{ .fd = input.handle },
    };
    _ = std.os.linux.epoll_ctl(@intCast(self.epoll_fd), std.os.linux.EPOLL.CTL_ADD, read_event.data.fd, &read_event);

    return self;
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    _ = std.os.linux.tcsetattr(std.os.linux.STDIN_FILENO, .FLUSH, &self.orig_termios);
    _ = std.os.linux.close(self.epoll_fd);
    allocator.destroy(self);
}

pub fn blockInput(self: *@This(), timeout_ms: i32) !u8 {
    while (true) {
        const event_count = std.os.linux.epoll_wait(self.epoll_fd, self.events[0..], self.events.len, timeout_ms);
        if (event_count == 0) {
            continue;
        }
        for (self.events[0..event_count]) |ev| {
            var read_buffer: [1]u8 = undefined;
            const bytes_read = std.os.linux.read(ev.data.fd, read_buffer[0..], read_buffer.len);
            if (bytes_read == 0) {
                return error.zeroRead;
            } else {
                return read_buffer[0];
            }
        }

        unreachable;
    }

    _ = std.os.linux.close(self.epoll_fd);
    return 'q';
}
