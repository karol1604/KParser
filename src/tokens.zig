const std = @import("std");

pub const TokenType = union(enum) {
    Plus,
    Minus,
    Star,
    Slash,
    Caret,

    Bang,

    LParen,
    RParen,
    LSquare,
    RSquare,
    LBrace,
    RBrace,

    Equal,
    NotEqual,
    LessThan,
    GreaterThan,
    LessThanOrEqual,
    GreaterThanOrEqual,
    DoubleEqual,

    Comma,
    Dot,
    Semicolon,

    Identifier: []const u8,
    IntLiteral: i64,

    Eof,
};

pub fn token_type_to_string(token_type: TokenType) []const u8 {
    switch (token_type) {
        .Plus => return "+",
        .Minus => return "-",
        .Star => return "*",
        .Slash => return "/",
        .Caret => return "^",

        .Bang => return "!",

        .LParen => return "(",
        .RParen => return ")",
        .LSquare => return "[",
        .RSquare => return "]",
        .LBrace => return "{",
        .RBrace => return "}",

        .Equal => return "=",
        .NotEqual => return "!=",
        .LessThan => return "<",
        .GreaterThan => return ">",
        .LessThanOrEqual => return "<=",
        .GreaterThanOrEqual => return ">=",
        .DoubleEqual => return "==",

        .Comma => return ",",
        .Dot => return ".",
        .Semicolon => return ";",

        .Identifier => |name| return name,
        .IntLiteral => |_| return "IntLiteral",

        .Eof => return "<EOF>",
    }
}

pub const Span = struct {
    start: usize,
    size: usize,
};

pub const Token = struct {
    type: TokenType,
    pos: Span,
    line: usize,

    /// Returns a string representation of the token.
    pub fn to_string(self: *Token, alloc: std.mem.Allocator) []const u8 {
        const type_str = token_type_to_string(self.type);

        const pos_str = std.fmt.allocPrint(alloc, "({d}..{d})", .{ self.pos.start, self.pos.start + self.pos.size }) catch unreachable;
        defer alloc.free(pos_str);

        const line_str = std.fmt.allocPrint(alloc, "{d}", .{self.line}) catch unreachable;
        defer alloc.free(line_str);

        const result = std.fmt.allocPrint(alloc, "{s} at {s} on line {s}", .{ type_str, pos_str, line_str }) catch unreachable;
        return result;
    }
};
