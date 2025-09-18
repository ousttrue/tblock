const std = @import("std");
const input = @import("input.zig");

is: std.fs.File,
os: std.fs.File,
epoll_fd: i32,
signal_fd: i32,
events: [8]std.os.linux.epoll_event = undefined,
orig_termios: std.os.linux.termios = undefined,

pub fn setupStdout(stdout: std.fs.File) bool {
    _ = stdout;
    return true;
}

fn createSignalfd() usize {
    var mask = std.os.linux.sigemptyset();
    std.os.linux.sigaddset(&mask, std.os.linux.SIG.WINCH);
    // std.os.linux.sigaddset(&mask, std.os.linux.SIG.INT);
    // std.os.linux.sigaddset(&mask, std.os.linux.SIG.TERM);
    // std.os.linux.sigaddset(&mask, std.os.linux.SIG.USR1);
    // std.os.linux.sigaddset(&mask, std.os.linux.SIG.USR2);
    _ = std.os.linux.sigprocmask(std.os.linux.SIG.BLOCK, &mask, null);
    return std.os.linux.signalfd(-1, &mask, std.os.linux.SFD.CLOEXEC);
}

pub fn init(allocator: std.mem.Allocator, is: std.fs.File, os: std.fs.File) !*@This() {
    const self = try allocator.create(@This());

    // rawmode
    _ = std.os.linux.tcgetattr(is.handle, &self.orig_termios);
    var raw: std.os.linux.termios = self.orig_termios;
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    _ = std.os.linux.tcsetattr(is.handle, .FLUSH, &raw);

    // epoll
    self.* = .{
        .is = is,
        .os = os,
        .epoll_fd = @intCast(std.os.linux.epoll_create1(std.os.linux.EPOLL.CLOEXEC)),
        .signal_fd = @intCast(createSignalfd()),
    };

    {
        // add input fd
        var event = std.os.linux.epoll_event{
            .events = std.os.linux.EPOLL.IN,
            .data = std.os.linux.epoll_data{ .fd = is.handle },
        };
        _ = std.os.linux.epoll_ctl(
            self.epoll_fd,
            std.os.linux.EPOLL.CTL_ADD,
            event.data.fd,
            &event,
        );
    }
    {
        // ddd signal fd
        var event = std.os.linux.epoll_event{
            .events = std.os.linux.EPOLL.IN,
            .data = std.os.linux.epoll_data{ .fd = self.signal_fd },
        };
        _ = std.os.linux.epoll_ctl(
            self.epoll_fd,
            std.os.linux.EPOLL.CTL_ADD,
            event.data.fd,
            &event,
        );
    }

    return self;
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    _ = std.os.linux.tcsetattr(std.os.linux.STDIN_FILENO, .FLUSH, &self.orig_termios);
    _ = std.os.linux.close(self.signal_fd);
    _ = std.os.linux.close(self.epoll_fd);
    allocator.destroy(self);
}

pub fn getTermSize(self: *@This()) !input.TermSize {
    var ws: std.posix.winsize = undefined;
    if (std.posix.system.ioctl(self.os.handle, std.posix.T.IOCGWINSZ, &ws) == -1) {
        return error.TIOCGWINSZ;
    }
    return .{
        .rows = ws.row,
        .cols = ws.col,
    };
}

pub fn blockInput(self: *@This(), timeout_ms: i32) !input.Input {
    while (true) {
        const event_count = std.os.linux.epoll_wait(self.epoll_fd, self.events[0..], self.events.len, timeout_ms);
        if (event_count == 0) {
            continue;
        }

        for (self.events[0..event_count]) |ev| {
            if (ev.data.fd == self.is.handle) {
                var read_buffer: [1]u8 = undefined;
                const bytes_read = std.os.linux.read(ev.data.fd, read_buffer[0..], read_buffer.len);
                if (bytes_read == 0) {
                    return error.zeroRead;
                } else {
                    return .{ .key = .{
                        .char = read_buffer[0],
                    } };
                }
            } else if (ev.data.fd == self.signal_fd) {
                //
                var buf: [1]std.os.linux.signalfd_siginfo = undefined;
                if (@sizeOf(std.os.linux.signalfd_siginfo) != std.os.linux.read(
                    ev.data.fd,
                    @ptrCast(&buf),
                    @sizeOf(std.os.linux.signalfd_siginfo),
                )) {
                    return error.readSignalFd;
                }
                switch (buf[0].signo) {
                    std.os.linux.SIG.WINCH => {
                        return .{ .resize = try self.getTermSize() };
                    },
                    else => {},
                }
            }
        }

        unreachable;
    }

    _ = std.os.linux.close(self.epoll_fd);
    return 'q';
}
