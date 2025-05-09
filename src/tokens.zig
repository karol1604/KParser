const std = @import("std");
const span = @import("span.zig");

const Span = span.Span;

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

    Pipe,
    DoublePipe,
    Ampersand,
    DoubleAmpersand,

    True,
    False,

    Let,

    Comma,
    Dot,
    Semicolon,

    Identifier: []const u8,
    IntLiteral: i64,

    Eof,
};

pub const Keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "true", .True },
    .{ "false", .False },
    .{ "let", .Let },
});

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

        .Pipe => return "|",
        .DoublePipe => return "||",
        .Ampersand => return "&",
        .DoubleAmpersand => return "&&",

        .True => return "true",
        .False => return "false",

        .Let => return "let",

        .Comma => return ",",
        .Dot => return ".",
        .Semicolon => return ";",

        .Identifier => |name| return name,
        .IntLiteral => |_| return "IntLiteral",

        .Eof => return "<EOF>",
    }
}

pub const Token = struct {
    type: TokenType,
    span: Span,

    pub fn format(self: Token, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const type_str = token_type_to_string(self.type);
        switch (self.type) {
            .Identifier => |name| {
                try writer.print("Ident({s}) at ({d}..{d}) on line {d} (offset: [{d}..{d}])", .{
                    name,
                    self.span.start.column,
                    self.span.end.column,
                    self.span.start.line,
                    self.span.start.offset,
                    self.span.end.offset,
                });
            },
            .IntLiteral => |val| {
                try writer.print("IntLiteral({d}) at ({d}..{d}) on line {d} (offset: [{d}..{d}])", .{
                    val,
                    self.span.start.column,
                    self.span.end.column,
                    self.span.start.line,
                    self.span.start.offset,
                    self.span.end.offset,
                });
            },
            else => {
                try writer.print("{s} at ({d}..{d}) on line {d} (offset: [{d}..{d}])", .{
                    type_str,
                    self.span.start.column,
                    self.span.end.column,
                    self.span.start.line,
                    self.span.start.offset,
                    self.span.end.offset,
                });
            },
        }
    }
};
