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

    // Keywords
    KeywordLet,
    KeywordFn,
    KeywordRet,

    RightArrow,

    Comma,
    Dot,
    Semicolon,
    Colon,

    Identifier: []const u8,
    IntLiteral: i64,

    Eof,

    pub fn format(self: TokenType, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const typeStr = tokenTypeToString(self);
        try writer.print("{s}", .{typeStr});
    }
};

pub const Keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "true", .True },
    .{ "false", .False },
    .{ "let", .KeywordLet },
    .{ "fn", .KeywordFn },
    .{ "ret", .KeywordRet },
});

pub fn tokenTypeToString(tokenType: TokenType) []const u8 {
    switch (tokenType) {
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

        .KeywordLet => return "KWLet",
        .KeywordFn => return "KWFn",
        .KeywordRet => return "KWRet",

        .RightArrow => return "->",

        .Comma => return ",",
        .Dot => return ".",
        .Semicolon => return ";",
        .Colon => return ":",

        .Identifier => |name| return name,
        .IntLiteral => |_| return "IntLiteral",

        .Eof => return "<EOF>",
    }
}

pub const Token = struct {
    type: TokenType,
    span: Span,

    pub fn format(self: Token, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const typeStr = tokenTypeToString(self.type);
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
                    typeStr,
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
