const std = @import("std");

const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Action = @import("parser.zig").Action;

pub const Executor = struct {
    pub fn exec(writer: *Writer, actions: []const Action) !void {
        var i: usize = 0;
        return exec: switch (actions[i]) {
            .echo => |text| {
                try writer.print("{s}", .{text});

                i += 1;
                if (i >= actions.len) break :exec;
                continue :exec actions[i];
            },
            .exit => |digit| {
                std.process.exit(digit);

                i += 1;
                if (i >= actions.len) break :exec;
                continue :exec actions[i];
            },
            .type => |typ| {
                switch (typ) {
                    .builtin => |cmd| {
                        try writer.print("{s} is a shell builtin\n", .{cmd});
                    },
                    .builtout => |cmd| {
                        try writer.print("{s} is {s}\n", .{ cmd.@"0", cmd.@"1" });
                    },
                    .not_found => |cmd| {
                        try writer.print("{s}: not found\n", .{cmd});
                    },
                }

                i += 1;
                if (i >= actions.len) break :exec;
                continue :exec actions[i];
            },
            .none => {
                i += 1;

                if (i >= actions.len) break :exec;
                continue :exec actions[i];
            },
        };
    }
};
