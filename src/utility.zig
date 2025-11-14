const std = @import("std");

pub const Utility = struct {
    pub fn isSpace(ch: u8) bool {
        return switch (ch) {
            ' ', '\t', '\n', '\r' => true,
            else => false,
        };
    }
};
