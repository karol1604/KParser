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
    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        const type_str = token_type_to_string(self.type);
        try writer.print("{s} at ({d}..{d}) on line {d}", .{ type_str, self.pos.start, self.pos.start + self.pos.size, self.line });
    }
};
