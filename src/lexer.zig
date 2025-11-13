const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Token = union(enum) {
    chain: void,
    digit: usize,
    exit: void,
    literal: []const u8,
    eof: void,
};

pub const Lexer = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Lexer {
        return .{
            .allocator = allocator,
        };
    }

    pub fn scan(self: *Lexer, input: []const u8, diag: ?*[]const u8) ![]const Token {
        var tokens: std.ArrayList(Token) = try .initCapacity(self.allocator, 64);
        errdefer tokens.deinit(self.allocator);

        var current_input = input;
        while (current_input.len > 0) {
            current_input = scanSpace(current_input);
            if (current_input.len == 0) break;

            const tuple = switch (current_input[0]) {
                '0'...'9' => try scanDigit(current_input, diag),
                '"' => try scanLiteral(current_input, diag),
                'a'...'z', 'A'...'Z' => try scanKeyword(current_input, diag),
                else => {
                    if (diag) |d| d.* = current_input[0..1];
                    return error.UnknownCharacter;
                },
            };

            try tokens.append(self.allocator, tuple.@"1");
            current_input = tuple.@"0";
        }

        try tokens.append(self.allocator, .eof);
        return try tokens.toOwnedSlice(self.allocator);
    }

    fn scanSpace(input: []const u8) []const u8 {
        var i: usize = 0;
        return scan: switch (input[i]) {
            ' ', '\t', '\n', '\r' => if (i < input.len) {
                i += 1;
                continue :scan input[i];
            } else {
                break :scan input[i..];
            },
            else => break :scan input[i..],
        };
    }

    fn scanLiteral(input: []const u8, diag: ?*[]const u8) !struct { []const u8, Token } { // 递归解析改进
        var i: usize = 1;
        while (i < input.len and input[i] != '"') {
            i += 1;
        }

        if (i >= input.len) {
            if (diag) |d| d.* = input[0..i];
            return error.UnterminatedString;
        }

        const token: Token = .{ .literal = input[1..i] };

        return .{
            input[i + 1 ..],
            token,
        };
    }

    fn scanDigit(input: []const u8, diag: ?*[]const u8) !struct { []const u8, Token } {
        var i: usize = 0;
        while (i < input.len and std.ascii.isDigit(input[i])) {
            i += 1;
        }

        const value = std.fmt.parseUnsigned(usize, input[0..i], 10) catch {
            if (diag) |d| d.* = input[0..i];
            return error.InvalidDigit;
        };

        const token: Token = .{ .digit = value };

        return .{
            input[i..],
            token,
        };
    }

    fn scanKeyword(input: []const u8, diag: ?*[]const u8) !struct { []const u8, Token } {
        var i: usize = 0;
        while (i < input.len and (std.ascii.isAlphanumeric(input[i]) or input[i] == '_')) {
            i += 1;
        }

        const keyword_slice = input[0..i];

        const token: Token = if (std.mem.eql(u8, keyword_slice, "exit"))
            .{ .exit = {} }
        else if (std.mem.eql(u8, keyword_slice, "&&"))
            .{ .chain = {} }
        else {
            if (diag) |d| d.* = keyword_slice;
            return error.UnknownKeyword;
        };

        return .{
            input[i..],
            token,
        };
    }
};
