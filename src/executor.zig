const std = @import("std");

const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Action = @import("parser.zig").Action;

pub const Executor = struct {
    pub fn exec(writer: *Writer, actions: []const Action) !void {
        var i: usize = 0;
        return exec: switch (actions[i]) {
            .echo => |action| {
                try writer.print("{s}", .{action});

                i += 1;
                if (i >= actions.len) break :exec;
                continue :exec actions[i];
            },
            .exit => |action| {
                std.process.exit(action);

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
