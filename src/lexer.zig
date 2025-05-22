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
    utf8Iter: std.unicode.Utf8Iterator,

    pub fn init(source: []const u8, alloc: std.mem.Allocator) !Lexer {
        const tokens = std.ArrayList(Token).init(alloc);
        errdefer tokens.deinit();

        return .{
            .source = source,
            .tokens = tokens,
            .alloc = alloc,
            .utf8Iter = (try std.unicode.Utf8View.init(source)).iterator(),
        };
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

    fn advance(self: *Lexer) !u21 {
        // const c = @as(u21, self.source[self.current]);
        // self.current += 1;
        const c = self.utf8Iter.nextCodepoint() orelse 0;

        // if (c_) |c| {
        var buf_c: [4]u8 = undefined;
        const utf8_bytes = try utils.encodeCodepointToUtf8(c, &buf_c);
        self.current += utf8_bytes.len;
        std.debug.print(">>>>>>>> advance on char: {d}:`{s}`\n", .{ c, utf8_bytes });
        std.debug.print("advancing by {d} bytes\n", .{utf8_bytes.len});

        if (c == '\n') {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }
        // } else std.debug.print("GOT NULL\n", .{});
        //
        return c; //_ orelse 0;
    }

    fn peek(self: *const Lexer, _: usize) u21 {
        var it = self.utf8Iter;
        return it.nextCodepoint() orelse 0;
        // if (self.current + offset >= self.source.len) {
        //     return 0; // Return null byte for end-of-file or out-of-bounds
        // }
        // return self.source[self.current + offset];
    }

    fn match(self: *Lexer, expected: u21) !bool {
        if (self.isAtEnd() or self.source[self.current] != expected) return false;

        _ = try self.advance();
        return true;
    }

    fn makeNumber(self: *Lexer, start: Location) !void {
        std.debug.print("Making number for `{d}`\n", .{self.peek(0)});
        while (utils.isDigit(self.peek(0))) {
            _ = try self.advance();
        }
        const tokSpan = Span{ .start = start, .end = self.currentLocation() };
        const i = try std.fmt.parseInt(i64, self.source[tokSpan.start.offset..tokSpan.end.offset], 10);

        try self.addToken(.{ .IntLiteral = i }, Span{ .start = start, .end = self.currentLocation() });
    }

    fn makeIdent(self: *Lexer, start: Location) !void {
        while (utils.isAlphaNumeric(self.peek(0)) or utils.isSpecial(self.peek(0))) {
            _ = try self.advance();
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
        const c = try self.advance();

        var buf_c: [4]u8 = undefined;
        const utf8_bytes = try utils.encodeCodepointToUtf8(c, &buf_c);

        std.debug.print("lexing char: {d}:`{s}`\n", .{ c, utf8_bytes });

        // var buff: [4]u8 = undefined;
        // const cr = try utils.encodeCodepointToUtf8(c, &buff);

        switch (c) {
            // ' ', '\t' => _ = try self.advance(),
            //
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
                const matches_arrow = try self.match('>');
                const matches_comment = try self.match('-');

                if (matches_comment) {
                    while (self.peek(0) != '\n' and !self.isAtEnd()) {
                        _ = try self.advance();
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
                const matches = try self.match('=');
                try self.addToken(if (matches) .LessThanOrEqual else .LessThan, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '>' => {
                const matches = try self.match('=');
                try self.addToken(if (matches) .GreaterThanOrEqual else .GreaterThan, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '=' => {
                const matches = try self.match('=');
                try self.addToken(if (matches) .DoubleEqual else .Equal, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '!' => {
                const matches = try self.match('=');
                try self.addToken(if (matches) .NotEqual else .Bang, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '|' => {
                const matches = try self.match('|');
                try self.addToken(if (matches) .DoublePipe else .Pipe, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '&' => {
                const matches = try self.match('&');
                try self.addToken(if (matches) .DoubleAmpersand else .Ampersand, .{ .start = tokStartLoc, .end = self.currentLocation() });
            },

            '0'...'9' => {
                try self.makeNumber(tokStartLoc);
            },

            'a'...'z', 'A'...'Z', '_' => {
                try self.makeIdent(tokStartLoc);
            },
            'ℝ', 'ℕ', 215, 955 => {
                // try self.addToken(.Star, .{ .start = tokStartLoc, .end = self.currentLocation() });
                try self.makeIdent(tokStartLoc);
                std.debug.print("WE GOT IT\n", .{});
            }, // TODO: remove this
            else => {
                var buf: [4]u8 = undefined;
                const utf8C = try utils.encodeCodepointToUtf8(c, &buf);
                std.debug.print("Invalid character: `{s}`[c={d}] on line {d}:{d}\n", .{ utf8C, c, self.line, self.col });
                return LexerError.InvalidCharacter;
            },
        }
    }

    pub fn tokenize(self: *Lexer) !void {
        // var utf8 = (try std.unicode.Utf8View.init(self.source)).iterator();

        while (!self.isAtEnd()) {
            // while (self.utf8Iter.nextCodepoint()) |c| {
            // const c_ = self.utf8Iter.nextCodepoint();

            // if (c_) |c| {

            const c = self.peek(0);
            std.debug.print("CCCCCCCCCCCCCCC char: {d}\n", .{c});
            if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                _ = try self.advance();
                continue;
            }

            const startLoc = self.currentLocation();
            // std.debug.print("Passing in char to lex: {d}\n", .{c});
            try self.makeToken(startLoc);
        }
        // } else break;
        // }
        try self.addToken(.Eof, Span{ .start = self.currentLocation(), .end = self.currentLocation() });
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }
};
