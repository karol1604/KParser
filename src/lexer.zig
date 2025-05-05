const std = @import("std");
const token = @import("tokens.zig");
const utils = @import("utils.zig");
const err = @import("errors.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const Span = token.Span;
const LexerError = err.LexerError;

pub const Lexer = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    alloc: std.mem.Allocator,
    current: usize = 0,
    line: usize = 1,
    start: usize = 0,

    pub fn init(source: []const u8, alloc: std.mem.Allocator) !Lexer {
        const tokens = std.ArrayList(Token).init(alloc);
        errdefer tokens.deinit();

        return .{ .source = source, .tokens = tokens, .alloc = alloc };
    }

    fn is_at_end(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        return c;
    }

    fn peek(self: *Lexer, offset: u8) u8 {
        if (self.current + @as(usize, offset) >= self.source.len) {
            return 0; // Return null byte for end-of-file or out-of-bounds
        }
        return self.source[self.current + offset];
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.is_at_end()) return false;
        if (self.source[self.current] != expected) return false;

        self.current += 1;
        return true;
    }

    fn make_number(self: *Lexer) !void {
        while (utils.is_digit(self.peek(0))) {
            _ = self.advance();
        }
        const i = try std.fmt.parseInt(i64, self.source[self.start..self.current], 10);

        try self.add_token(.{ .IntLiteral = i }, Span{ .start = self.start, .size = self.current - self.start }, self.line);
    }

    fn make_ident(self: *Lexer) !void {
        while (utils.is_alpha_numeric(self.peek(0))) {
            _ = self.advance();
        }
        const ident = self.source[self.start..self.current];
        try self.add_token(.{ .Identifier = ident }, Span{ .start = self.start, .size = self.current - self.start }, self.line);
    }

    fn add_token(self: *Lexer, token_type: TokenType, pos: Span, line: usize) !void {
        const tok = Token{
            .type = token_type,
            .pos = pos,
            .line = line,
        };
        try self.tokens.append(tok);
    }

    fn make_token(self: *Lexer) anyerror!void {
        const c = self.advance();

        switch (c) {
            ' ', '\r', '\t' => {},

            '\n' => self.line += 1,

            ',' => try self.add_token(.Comma, Span{ .start = self.start, .size = 1 }, self.line),
            '.' => try self.add_token(.Dot, Span{ .start = self.start, .size = 1 }, self.line),
            ';' => try self.add_token(.Semicolon, Span{ .start = self.start, .size = 1 }, self.line),

            '+' => try self.add_token(.Plus, Span{ .start = self.start, .size = 1 }, self.line),
            '-' => try self.add_token(.Minus, Span{ .start = self.start, .size = 1 }, self.line),
            '*' => try self.add_token(.Star, Span{ .start = self.start, .size = 1 }, self.line),
            '/' => try self.add_token(.Slash, Span{ .start = self.start, .size = 1 }, self.line),
            '^' => try self.add_token(.Caret, Span{ .start = self.start, .size = 1 }, self.line),

            '(' => try self.add_token(.LParen, Span{ .start = self.start, .size = 1 }, self.line),
            ')' => try self.add_token(.RParen, Span{ .start = self.start, .size = 1 }, self.line),
            '[' => try self.add_token(.LSquare, Span{ .start = self.start, .size = 1 }, self.line),
            ']' => try self.add_token(.RSquare, Span{ .start = self.start, .size = 1 }, self.line),
            '{' => try self.add_token(.LBrace, Span{ .start = self.start, .size = 1 }, self.line),
            '}' => try self.add_token(.RBrace, Span{ .start = self.start, .size = 1 }, self.line),

            '<' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .LessThanOrEqual else .LessThan, Span{ .start = self.start, .size = if (matches) 2 else 1 }, self.line);
            },

            '>' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .GreaterThanOrEqual else .GreaterThan, Span{ .start = self.start, .size = if (matches) 2 else 1 }, self.line);
            },

            '=' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .DoubleEqual else .Equal, Span{ .start = self.start, .size = if (matches) 2 else 1 }, self.line);
            },

            '!' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .NotEqual else .Bang, Span{ .start = self.start, .size = if (matches) 2 else 1 }, self.line);
            },

            '|' => {
                const matches = self.match('|');
                try self.add_token(if (matches) .DoublePipe else .Pipe, Span{ .start = self.start, .size = if (matches) 2 else 1 }, self.line);
            },

            '&' => {
                const matches = self.match('&');
                try self.add_token(if (matches) .DoubleAmpersand else .Ampersand, Span{ .start = self.start, .size = if (matches) 2 else 1 }, self.line);
            },

            '0'...'9' => {
                try self.make_number();
            },

            'a'...'z', 'A'...'Z', '_' => {
                try self.make_ident();
            },
            else => {
                return LexerError.InvalidCharacter;
            },
        }
    }

    pub fn tokenize(self: *Lexer) !void {
        while (!self.is_at_end()) {
            self.start = self.current;
            try self.make_token();
        }
        try self.add_token(.Eof, Span{ .start = self.start, .size = 0 }, self.line);
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }
};
