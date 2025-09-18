pub const TermSize = struct {
    rows: i32,
    cols: i32,
};

pub const Input = union(enum) {
    resize: TermSize,
    key: struct { char: u8 },
};
