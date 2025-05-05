const std = @import("std");
const token = @import("tokens.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const Span = token.Span;

pub const Lexer = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    current: usize = 0,
    line: usize = 1,
    start: usize = 0,

    pub fn init(source: []const u8) !Lexer {
        const tokens = std.ArrayList(Token).init(std.heap.page_allocator);
        return .{ .source = source, .tokens = tokens };
    }

    fn is_at_end(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        return c;
    }

    fn add_token(self: *Lexer, token_type: TokenType, pos: Span, line: usize) !void {
        const tok = Token{
            .type = token_type,
            .pos = pos,
            .line = line,
        };
        try self.tokens.append(tok);
    }

    fn make_token(self: *Lexer) !void {
        const c = self.advance();

        switch (c) {
            ' ', '\r', '\t' => {},

            '\n' => self.line += 1,

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
            else => {},
        }
    }

    pub fn tokenize(self: *Lexer) !void {
        while (!self.is_at_end()) {
            self.start = self.current;
            try self.make_token();
        }
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }
};
