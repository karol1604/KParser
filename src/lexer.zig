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
    alloc: std.mem.Allocator,
    current: usize = 0, // offset
    line: usize = 1, // current line
    col: usize = 1, // current column
    utf8Iter: std.unicode.Utf8Iterator,

    pub fn init(source: []const u8, alloc: std.mem.Allocator) !Lexer {
        return .{
            .source = source,
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

    fn makeNumber(self: *Lexer, start: Location) !Token {
        while (utils.isDigit(self.peek(0))) {
            _ = try self.advance();
        }
        const tokSpan = Span{ .start = start, .end = self.currentLocation() };
        const i = try std.fmt.parseInt(i64, self.source[tokSpan.start.offset..tokSpan.end.offset], 10);

        return .{ .type = .{ .IntLiteral = i }, .span = Span{ .start = start, .end = self.currentLocation() } };
    }

    fn makeIdent(self: *Lexer, start: Location) !Token {
        while (utils.isAlphaNumeric(self.peek(0)) or utils.isSpecial(self.peek(0))) {
            _ = try self.advance();
        }

        const tokSpan = Span{ .start = start, .end = self.currentLocation() };
        const ident = self.source[tokSpan.start.offset..tokSpan.end.offset];

        const tokType = Keywords.get(ident);

        if (tokType) |typ| {
            // try self.addToken(typ, tokSpan);
            return .{ .type = typ, .span = tokSpan };
        }
        return .{ .type = .{ .Identifier = ident }, .span = tokSpan };
    }

    fn makeToken(self: *Lexer, tokStartLoc: Location) !?Token {
        const c = try self.advance();

        switch (c) {
            // ' ', '\t' => _ = try self.advance(),
            //
            // '\n' => {
            //     self.line += 1;
            //     self.col = 1;
            // },

            ',' => return .{ .type = .Comma, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            '.' => return .{ .type = .Dot, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            ';' => return .{ .type = .Semicolon, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            ':' => return .{ .type = .Colon, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },

            '+' => return .{ .type = .Plus, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            '-' => {
                const matches_arrow = try self.match('>');
                const matches_comment = try self.match('-');

                if (matches_comment) {
                    while (self.peek(0) != '\n' and !self.isAtEnd()) {
                        _ = try self.advance();
                    }
                    return null;
                }

                return .{ .type = if (matches_arrow) .RightArrow else .Minus, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } };
            },
            '*' => return .{ .type = .Star, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            '/' => return .{ .type = .Slash, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            '^' => return .{ .type = .Caret, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },

            '(' => return .{ .type = .LParen, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            ')' => return .{ .type = .RParen, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            '[' => return .{ .type = .LSquare, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            ']' => return .{ .type = .RSquare, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            '{' => return .{ .type = .LBrace, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },
            '}' => return .{ .type = .RBrace, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } },

            '<' => {
                const matches = try self.match('=');
                return .{ .type = if (matches) .LessThanOrEqual else .LessThan, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } };
            },

            '>' => {
                const matches = try self.match('=');
                return .{ .type = if (matches) .GreaterThanOrEqual else .GreaterThan, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } };
            },

            '=' => {
                const matches = try self.match('=');
                return .{ .type = if (matches) .DoubleEqual else .Equal, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } };
            },

            '!' => {
                const matches = try self.match('=');
                return .{ .type = if (matches) .NotEqual else .Bang, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } };
            },

            '|' => {
                const matches = try self.match('|');
                return .{ .type = if (matches) .DoublePipe else .Pipe, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } };
            },

            '&' => {
                const matches = try self.match('&');
                return .{ .type = if (matches) .DoubleAmpersand else .Ampersand, .span = .{ .start = tokStartLoc, .end = self.currentLocation() } };
            },

            '0'...'9' => {
                return try self.makeNumber(tokStartLoc);
            },

            'a'...'z', 'A'...'Z', '_' => {
                return try self.makeIdent(tokStartLoc);
            },
            // NOTE: this is kinda stupid tbh, should change it
            'ℝ', 'ℕ', 215, 955, 8484, 8709 => {
                return try self.makeIdent(tokStartLoc);
            },
            else => {
                // TODO: remove this
                var buf: [4]u8 = undefined;
                const utf8C = try utils.encodeCodepointToUtf8(c, &buf);
                std.debug.print("Invalid character: `{s}`[c={d}] on line {d}:{d}\n", .{ utf8C, c, self.line, self.col });
                return LexerError.InvalidCharacter;
            },
        }
    }

    pub fn tokenize(self: *Lexer) ![]Token {
        var toks = std.ArrayList(Token).init(self.alloc);

        while (!self.isAtEnd()) {
            const c = self.peek(0);
            if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                _ = try self.advance();
                continue;
            }

            const startLoc = self.currentLocation();
            const tok = try self.makeToken(startLoc);
            // const tok = try self.makeToken(startLoc);
            if (tok) |t| try toks.append(t);
        }

        // try self.addToken(.Eof, Span{ .start = self.currentLocation(), .end = self.currentLocation() });
        try toks.append(.{ .type = .Eof, .span = Span{ .start = self.currentLocation(), .end = self.currentLocation() } });
        return toks.items;
    }

    pub fn deinit(self: *Lexer) void {
        _ = self;
    }
};
