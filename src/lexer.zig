const std = @import("std");
const token = @import("tokens.zig");
const utils = @import("utils.zig");
const err = @import("errors.zig");
const span = @import("span.zig");

const Token = token.Token;
const Keywords = token.Keywords;
const TokenType = token.TokenType;
const Span = span.Span;
const Location = span.Location;
const LexerError = err.LexerErrorType;

pub const Lexer = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    alloc: std.mem.Allocator,
    current: usize = 0, // offset
    line: usize = 1, // current line
    col: usize = 1, // current column

    pub fn init(source: []const u8, alloc: std.mem.Allocator) !Lexer {
        const tokens = std.ArrayList(Token).init(alloc);
        errdefer tokens.deinit();

        return .{ .source = source, .tokens = tokens, .alloc = alloc };
    }

    fn is_at_end(self: *const Lexer) bool {
        return self.current >= self.source.len;
    }

    fn current_location(self: *const Lexer) Location {
        return Location{
            .offset = self.current,
            .line = self.line,
            .column = self.col,
        };
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;

        if (c == '\n') {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }

        return c;
    }

    fn peek(self: *const Lexer, offset: usize) u8 {
        if (self.current + offset >= self.source.len) {
            return 0; // Return null byte for end-of-file or out-of-bounds
        }
        return self.source[self.current + offset];
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.is_at_end() or self.source[self.current] != expected) return false;

        _ = self.advance();
        return true;
    }

    fn make_number(self: *Lexer, start: Location) !void {
        while (utils.is_digit(self.peek(0))) {
            _ = self.advance();
        }
        const tok_span = Span{ .start = start, .end = self.current_location() };
        const i = try std.fmt.parseInt(i64, self.source[tok_span.start.offset..tok_span.end.offset], 10);

        try self.add_token(.{ .IntLiteral = i }, Span{ .start = start, .end = self.current_location() });
    }

    fn make_ident(self: *Lexer, start: Location) !void {
        while (utils.is_alpha_numeric(self.peek(0))) {
            _ = self.advance();
        }

        const tok_span = Span{ .start = start, .end = self.current_location() };
        const ident = self.source[tok_span.start.offset..tok_span.end.offset];

        const tok_type = Keywords.get(ident);

        if (tok_type) |typ| {
            try self.add_token(typ, tok_span);
            return;
        }
        try self.add_token(.{ .Identifier = ident }, tok_span);
    }

    fn add_token(self: *Lexer, token_type: TokenType, span_: Span) !void {
        const tok = Token{
            .type = token_type,
            .span = span_,
        };
        try self.tokens.append(tok);
    }

    fn make_token(self: *Lexer, tok_start_loc: Location) !void {
        const c = self.advance();

        switch (c) {
            // ' ', '\t' => {
            //     // idk what to do for the \t
            // },

            // '\n' => {
            //     self.line += 1;
            //     self.col = 1;
            // },

            ',' => try self.add_token(.Comma, .{ .start = tok_start_loc, .end = self.current_location() }),
            '.' => try self.add_token(.Dot, .{ .start = tok_start_loc, .end = self.current_location() }),
            ';' => try self.add_token(.Semicolon, .{ .start = tok_start_loc, .end = self.current_location() }),

            '+' => try self.add_token(.Plus, .{ .start = tok_start_loc, .end = self.current_location() }),
            '-' => try self.add_token(.Minus, .{ .start = tok_start_loc, .end = self.current_location() }),
            '*' => try self.add_token(.Star, .{ .start = tok_start_loc, .end = self.current_location() }),
            '/' => try self.add_token(.Slash, .{ .start = tok_start_loc, .end = self.current_location() }),
            '^' => try self.add_token(.Caret, .{ .start = tok_start_loc, .end = self.current_location() }),

            '(' => try self.add_token(.LParen, .{ .start = tok_start_loc, .end = self.current_location() }),
            ')' => try self.add_token(.RParen, .{ .start = tok_start_loc, .end = self.current_location() }),
            '[' => try self.add_token(.LSquare, .{ .start = tok_start_loc, .end = self.current_location() }),
            ']' => try self.add_token(.RSquare, .{ .start = tok_start_loc, .end = self.current_location() }),
            '{' => try self.add_token(.LBrace, .{ .start = tok_start_loc, .end = self.current_location() }),
            '}' => try self.add_token(.RBrace, .{ .start = tok_start_loc, .end = self.current_location() }),

            '<' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .LessThanOrEqual else .LessThan, .{ .start = tok_start_loc, .end = self.current_location() });
            },

            '>' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .GreaterThanOrEqual else .GreaterThan, .{ .start = tok_start_loc, .end = self.current_location() });
            },

            '=' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .DoubleEqual else .Equal, .{ .start = tok_start_loc, .end = self.current_location() });
            },

            '!' => {
                const matches = self.match('=');
                try self.add_token(if (matches) .NotEqual else .Bang, .{ .start = tok_start_loc, .end = self.current_location() });
            },

            '|' => {
                const matches = self.match('|');
                try self.add_token(if (matches) .DoublePipe else .Pipe, .{ .start = tok_start_loc, .end = self.current_location() });
            },

            '&' => {
                const matches = self.match('&');
                try self.add_token(if (matches) .DoubleAmpersand else .Ampersand, .{ .start = tok_start_loc, .end = self.current_location() });
            },

            '0'...'9' => {
                try self.make_number(tok_start_loc);
            },
            //
            'a'...'z', 'A'...'Z', '_' => {
                try self.make_ident(tok_start_loc);
            },
            else => {
                return LexerError.InvalidCharacter;
            },
        }
    }

    pub fn tokenize(self: *Lexer) !void {
        while (!self.is_at_end()) {
            const start_loc = self.current_location();

            const c = self.peek(0);
            if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                _ = self.advance();
                continue;
            }

            try self.make_token(start_loc);
        }
        try self.add_token(.Eof, Span{ .start = self.current_location(), .end = self.current_location() });
    }

    pub fn dummy(self: *Lexer, idx: usize) err.LexerResult {
        return err.LexerResult{
            .err = .{
                .type = LexerError.InvalidCharacter,
                .token = self.tokens.items[idx],
                .message = "Dummy error",
                .source = self.source,
            },
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }
};
