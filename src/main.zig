const std = @import("std");

const Allocator = std.mem.Allocator;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;
const Parser = @import("parser.zig").Parser;
const Executor = @import("executor.zig").Executor;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    const gpa = debug_allocator.allocator();

    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writerStreaming(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var error_buffer: []const u8 = undefined;

    while (true) {
        try stdout.print("$ ", .{});
        try stdout.flush();

        const input = (try stdin.takeDelimiter('\n')).?;

        var lexer = Lexer.init(gpa);
        const tokens = lexer.scan(input, &error_buffer) catch |err| {
            switch (err) {
                error.UnknownKeyword => try stdout.print("{s}: command not found\n", .{error_buffer}),
                else => try stdout.print("unknown error\n", .{}),
            }

            try stdout.flush();
            continue;
        };

        var parser = Parser.init(gpa);
        const actions = parser.parse(tokens, &error_buffer) catch |err| {
            switch (err) {
                else => try stdout.print("unknown error\n", .{}),
            }

            try stdout.flush();
            continue;
        };

        Executor.exec(actions);
    }
}
