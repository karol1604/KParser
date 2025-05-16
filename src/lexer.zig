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

    fn isAtEnd(self: *const Lexer) bool {
        return self.current >= self.source.len;
    }

    fn currentLocation(self: *const Lexer) Location {
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
        if (self.isAtEnd() or self.source[self.current] != expected) return false;

        _ = self.advance();
        return true;
    }

    fn makeNumber(self: *Lexer, start: Location) !void {
        while (utils.isDigit(self.peek(0))) {
            _ = self.advance();
        }
        const tokSpan = Span{ .start = start, .end = self.currentLocation() };
        const i = try std.fmt.parseInt(i64, self.source[tokSpan.start.offset..tokSpan.end.offset], 10);

        try self.addToken(.{ .IntLiteral = i }, Span{ .start = start, .end = self.currentLocation() });
    }

    fn makeIdent(self: *Lexer, start: Location) !void {
        while (utils.isAlphaNumeric(self.peek(0))) {
            _ = self.advance();
        }

        const tokSpan = Span{ .start = start, .end = self.currentLocation() };
        const ident = self.source[tokSpan.start.offset..tokSpan.end.offset];

        const tokType = Keywords.get(ident);

        if (tokType) |typ| {
            try self.addToken(typ, tokSpan);
            return;
        }
        try self.addToken(.{ .Identifier = ident }, tokSpan);
    }

    fn addToken(self: *Lexer, tokenType: TokenType, span_: Span) !void {
        const tok = Token{
            .type = tokenType,
            .span = span_,
        };
        try self.tokens.append(tok);
    }

    fn makeToken(self: *Lexer, tokStartLoc: Location) !void {
        const c = self.advance();

        switch (c) {
            // ' ', '\t' => {
            //     // idk what to do for the \t
            // },

            // '\n' => {
            //     self.line += 1;
            //     self.col = 1;
            // },

            ',' => try self.addToken(.Comma, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            '.' => try self.addToken(.Dot, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            ';' => try self.addToken(.Semicolon, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            ':' => try self.addToken(.Colon, .{ .start = tokStartLoc, .end = self.currentLocation() }),

            '+' => try self.addToken(.Plus, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            '-' => {
                const matches_arrow = self.match('>');
                const matches_comment = self.match('-');

                if (matches_comment) {
                    while (self.peek(0) != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                    return;
                }

                try self.addToken(if (matches_arrow) .RightArrow else .Minus, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },
            '*' => try self.addToken(.Star, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            '/' => try self.addToken(.Slash, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            '^' => try self.addToken(.Caret, .{ .start = tokStartLoc, .end = self.currentLocation() }),

            '(' => try self.addToken(.LParen, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            ')' => try self.addToken(.RParen, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            '[' => try self.addToken(.LSquare, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            ']' => try self.addToken(.RSquare, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            '{' => try self.addToken(.LBrace, .{ .start = tokStartLoc, .end = self.currentLocation() }),
            '}' => try self.addToken(.RBrace, .{ .start = tokStartLoc, .end = self.currentLocation() }),

            '<' => {
                const matches = self.match('=');
                try self.addToken(if (matches) .LessThanOrEqual else .LessThan, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '>' => {
                const matches = self.match('=');
                try self.addToken(if (matches) .GreaterThanOrEqual else .GreaterThan, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '=' => {
                const matches = self.match('=');
                try self.addToken(if (matches) .DoubleEqual else .Equal, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '!' => {
                const matches = self.match('=');
                try self.addToken(if (matches) .NotEqual else .Bang, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '|' => {
                const matches = self.match('|');
                try self.addToken(if (matches) .DoublePipe else .Pipe, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '&' => {
                const matches = self.match('&');
                try self.addToken(if (matches) .DoubleAmpersand else .Ampersand, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '0'...'9' => {
                try self.makeNumber(tokStartLoc);
            },
            //
            'a'...'z', 'A'...'Z', '_' => {
                try self.makeIdent(tokStartLoc);
            },
            else => {
                return LexerError.InvalidCharacter;
            },
        }
    }

    pub fn tokenize(self: *Lexer) !void {
        while (!self.isAtEnd()) {
            const startLoc = self.currentLocation();

            const c = self.peek(0);
            if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                _ = self.advance();
                continue;
            }

            try self.makeToken(startLoc);
        }
        try self.addToken(.Eof, Span{ .start = self.currentLocation(), .end = self.currentLocation() });
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
