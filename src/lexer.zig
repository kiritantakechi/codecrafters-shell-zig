const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Token = union(enum) {
    bareword: []const u8,
    chain: void,
    pipe: void,
    digit: usize,
    space: []const u8,
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
            if (current_input.len == 0) break;

            const scan_tuple = switch (current_input[0]) {
                ' ', '\t', '\n', '\r' => scanSpace(current_input),
                '&' => try scanOperator(current_input, diag),
                '0'...'9' => try scanDigit(current_input, diag),
                'a'...'z', 'A'...'Z' => try scanBareword(current_input, diag),
                else => {
                    if (diag) |d| d.* = current_input[0..1];
                    return error.UnknownCharacter;
                },
            };

            try tokens.append(self.allocator, scan_tuple.@"1");
            current_input = scan_tuple.@"0";
        }

        try tokens.append(self.allocator, .eof);
        return try tokens.toOwnedSlice(self.allocator);
    }

    fn scanSpace(input: []const u8) struct { []const u8, Token } {
        var i: usize = 0;
        return scan: switch (input[i]) {
            ' ', '\t', '\n', '\r' => {
                i += 1;

                if (i >= input.len) break :scan .{ input[i..], .{ .space = input[0..i] } };
                continue :scan input[i];
            },
            else => break :scan .{ input[i..], .{ .space = input[0..i] } },
        };
    }

    fn scanOperator(input: []const u8, diag: ?*[]const u8) !struct { []const u8, Token } {
        var i: usize = 0;
        while (i < input.len and !isSpace(input[i])) : (i += 1) {}

        const operator_slice = input[0..i];

        const token: Token = if (std.mem.eql(u8, operator_slice, "&&"))
            .chain
        else {
            if (diag) |d| d.* = operator_slice;
            return error.UnknownOperator;
        };

        return .{
            input[i..],
            token,
        };
    }

    fn scanBareword(input: []const u8, diag: ?*[]const u8) !struct { []const u8, Token } {
        var i: usize = 0;
        var flag: bool = false;
        while (i < input.len and !isSpace(input[i])) : (i += 1) {
            if (!(std.ascii.isAlphanumeric(input[i]) or input[i] == '_')) flag = true;
        }

        const bareword_slice = input[0..i];

        if (flag) {
            if (diag) |d| d.* = bareword_slice;
            return error.InvalidBareword;
        }

        const token: Token = .{ .bareword = bareword_slice };

        return .{
            input[i..],
            token,
        };
    }

    fn scanDigit(input: []const u8, diag: ?*[]const u8) !struct { []const u8, Token } {
        var i: usize = 0;
        var flag: bool = false;
        while (i < input.len and !isSpace(input[i])) : (i += 1) {
            if (!(std.ascii.isDigit(input[i]))) flag = true;
        }

        const digit_slice = input[0..i];

        if (flag) {
            if (diag) |d| d.* = digit_slice;
            return error.InvalidDigit;
        }

        const value = std.fmt.parseUnsigned(usize, digit_slice, 10) catch {
            if (diag) |d| d.* = digit_slice;
            return error.InvalidDigit;
        };

        const token: Token = .{ .digit = value };

        return .{
            input[i..],
            token,
        };
    }

    fn isSpace(ch: u8) bool {
        return switch (ch) {
            ' ', '\t', '\n', '\r' => true,
            else => false,
        };
    }
};
