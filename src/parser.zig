const std = @import("std");

const Allocator = std.mem.Allocator;
const Token = @import("lexer.zig").Token;

pub const Action = union(enum) {
    echo: []const u8,
    exit: u8,
    type: CommandType,
    none: void,
};

pub const CommandType = union(enum) {
    builtin: []const u8,
    builtout: struct { []const u8, []const u8 },
    not_found: []const u8,
};

pub const Parser = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Parser {
        return .{
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Parser, tokens: []const Token, diag: ?*[]const u8) ![]const Action {
        var actions: std.ArrayList(Action) = try .initCapacity(self.allocator, 64);
        errdefer actions.deinit(self.allocator);

        var i: usize = 0;
        return parse: switch (tokens[i]) {
            .eof => {
                try actions.append(self.allocator, .none);

                break :parse try actions.toOwnedSlice(self.allocator);
            },
            .space => {
                i += 1;
                continue :parse tokens[i];
            },
            .bareword => |word| {
                const tuple = try self.parseBareword(tokens[i + 1 ..], word, diag);
                try actions.appendSlice(self.allocator, tuple.@"1");

                i = 0;
                if (i >= tuple.@"0".len) break :parse try actions.toOwnedSlice(self.allocator);
                continue :parse tuple.@"0"[i];
            },
            else => |token| {
                if (i >= tokens.len) break :parse try actions.toOwnedSlice(self.allocator);

                if (diag) |d| d.* = @tagName(token);
                break :parse error.InvalidCommand;
            },
        };
    }

    fn parseBareword(self: *Parser, tokens: []const Token, word: []const u8, diag: ?*[]const u8) !struct { []const Token, []const Action } {
        return if (std.mem.eql(u8, word, "echo"))
            try self.parseEcho(tokens[0..], diag)
        else if (std.mem.eql(u8, word, "exit"))
            try self.parseExit(tokens[0..], diag)
        else if (std.mem.eql(u8, word, "type"))
            try self.parseType(tokens[0..], diag)
        else {
            if (diag) |d| d.* = word;
            return error.InvalidCommand;
        };
    }

    fn parseEcho(self: *Parser, tokens: []const Token, diag: ?*[]const u8) !struct { []const Token, []const Action } {
        var actions: std.ArrayList(Action) = try .initCapacity(self.allocator, 64);
        errdefer actions.deinit(self.allocator);

        var i: usize = 0;
        return parse: switch (tokens[i]) {
            .eof => {
                try actions.append(self.allocator, .{ .echo = "\n" });

                i += 1;
                break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };
            },
            .space => |space| {
                if (i > 1) try actions.append(self.allocator, .{ .echo = space });

                i += 1;
                continue :parse tokens[i];
            },
            .chain => {
                try actions.append(self.allocator, .none);

                i += 1;
                break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };
            },
            .bareword => |word| {
                try actions.append(self.allocator, .{ .echo = word });

                i += 1;
                continue :parse tokens[i];
            },
            .digit => |digit| {
                const digit_str = try std.fmt.allocPrint(self.allocator, "{d}", .{digit});
                try actions.append(self.allocator, .{ .echo = digit_str });

                i += 1;
                continue :parse tokens[i];
            },
            else => |token| {
                if (i >= tokens.len) break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };

                if (diag) |d| d.* = @tagName(token);
                break :parse error.InvalidArgument;
            },
        };
    }

    fn parseExit(self: *Parser, tokens: []const Token, diag: ?*[]const u8) !struct { []const Token, []const Action } {
        var actions: std.ArrayList(Action) = try .initCapacity(self.allocator, 64);
        errdefer actions.deinit(self.allocator);

        var i: usize = 0;
        return parse: switch (tokens[i]) {
            .eof => {
                if (i < 2) try actions.append(self.allocator, .{ .exit = 0 });

                try actions.append(self.allocator, .none);

                i += 1;
                break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };
            },
            .space => {
                i += 1;
                continue :parse tokens[i];
            },
            .chain => {
                try actions.append(self.allocator, .none);

                i += 1;
                break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };
            },
            .digit => |digit| {
                try actions.append(self.allocator, .{ .exit = @intCast(digit) });

                i += 1;
                continue :parse tokens[i];
            },
            else => |token| {
                if (i >= tokens.len) break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };

                if (diag) |d| d.* = @tagName(token);
                break :parse error.InvalidArgument;
            },
        };
    }

    fn parseType(self: *Parser, tokens: []const Token, diag: ?*[]const u8) !struct { []const Token, []const Action } {
        var actions: std.ArrayList(Action) = try .initCapacity(self.allocator, 64);
        errdefer actions.deinit(self.allocator);

        var i: usize = 0;
        return parse: switch (tokens[i]) {
            .eof => {
                try actions.append(self.allocator, .none);

                i += 1;
                break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };
            },
            .space => {
                i += 1;
                continue :parse tokens[i];
            },
            .chain => {
                try actions.append(self.allocator, .none);

                i += 1;
                break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };
            },
            .bareword => |word| {
                if (isBuiltin(word))
                    try actions.append(self.allocator, .{ .type = .{ .builtin = word } })
                else
                    try actions.append(self.allocator, .{ .type = .{ .not_found = word } });

                i += 1;
                continue :parse tokens[i];
            },
            else => |token| {
                if (i >= tokens.len) break :parse .{ tokens[i..], try actions.toOwnedSlice(self.allocator) };

                if (diag) |d| d.* = @tagName(token);
                break :parse error.InvalidArgument;
            },
        };
    }
};

const BuiltinSet = std.StaticStringMap(void);

fn isBuiltin(input: []const u8) bool {
    const builtin_entries = comptime blk: {
        const fields = std.meta.fields(Action);

        var count: usize = 0;
        for (fields) |field| {
            if (!std.mem.eql(u8, field.name, "none")) {
                count += 1;
            }
        }

        var entries: [count]struct { []const u8, void } = undefined;

        var i: usize = 0;
        for (fields) |field| {
            if (!std.mem.eql(u8, field.name, "none")) {
                entries[i] = .{ field.name, {} };
                i += 1;
            }
        }

        break :blk entries;
    };

    const set = BuiltinSet.initComptime(builtin_entries);

    return set.has(input);
}
