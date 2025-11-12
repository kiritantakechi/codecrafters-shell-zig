const std = @import("std");

const Allocator = std.mem.Allocator;
const Token = @import("lexer.zig").Token;

pub const Action = union(enum) {
    exit: u8,
    none: void,
};

pub const Parser = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Parser {
        return .{
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Parser, tokens: []const Token) ![]const Action {
        var actions: std.ArrayList(Action) = try .initCapacity(self.allocator, 64);
        errdefer actions.deinit(self.allocator);

        var i: usize = 0;
        return parse: switch (tokens[i]) {
            .eof => {
                try actions.append(self.allocator, .none);

                i += 1;
                break :parse actions.toOwnedSlice(self.allocator);
            },
            .exit => {
                const result = try parseExit(tokens[i..]);
                try actions.append(self.allocator, result.@"1");

                i = 0;
                continue :parse result.@"0"[i];
            },
            else => {
                if (i >= tokens.len) break :parse actions.toOwnedSlice(self.allocator);
                break :parse error.UnknownCommand;
            },
        };
    }

    fn parseExit(tokens: []const Token) !struct { []const Token, Action } {
        var action: Action = .none;

        var i: usize = 0;
        return parse: switch (tokens[i]) {
            .eof => {
                action = .none;

                i += 1;
                break :parse .{ tokens[i..], action };
            },
            .chain => {
                action = .none;

                i += 1;
                break :parse .{ tokens[i..], action };
            },
            .digit => |token| {
                action = .{ .exit = @intCast(token) };

                i += 1;
                continue :parse tokens[i];
            },
            else => {
                if (i >= tokens.len) break :parse .{ tokens[i..], action };
                break :parse error.InvalidArgument;
            },
        };
    }
};
