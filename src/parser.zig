const std = @import("std");
const token = @import("tokens.zig");
const ast = @import("ast.zig");
const utils = @import("utils.zig");
const span = @import("span.zig");
const diagnostics = @import("diagnostics.zig");

const Token = token.Token;
const TokenType = token.TokenType;

const Span = span.Span;
const Location = span.Location;

const Precedence = ast.Precedence;
const Expression = ast.Expression;
const BinaryOperator = ast.BinaryOperator;
const UnaryOperator = ast.UnaryOperator;
const FunctionParameter = ast.FunctionParameter;

pub const Parser = struct {
    tokens: []const Token,
    alloc: std.mem.Allocator,
    current: usize = 0,
    // diagnostics: *std.ArrayList(Diagnostic),

    pub fn init(tokens: []const Token, alloc: std.mem.Allocator) Parser {
        return Parser{
            .tokens = tokens,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    fn makePointer(self: *const Parser, comptime T: type, value: T) !*T {
        const ptr = try self.alloc.create(T);
        ptr.* = value;
        return ptr;
    }

    pub fn parse(self: *Parser) ![]*Expression {
        var expressions = std.ArrayList(*Expression).init(self.alloc);
        errdefer expressions.deinit();

        while (self.currentToken().type != .Eof) {
            const expr = try self.parseTopLevelExpression();
            try expressions.append(expr);
        }

        return expressions.items;
    }

    fn parseTopLevelExpression(self: *Parser) !*Expression {
        const expr = try self.parseExpression(.Lowest);
        const startSpan = expr.span;
        var endSpan = startSpan;
        // Not sure about the first if part
        // if (self.peek().type == .Eof or self.currentToken().type == .Semicolon) {
        //     self.advance();
        // } else return error.ExpectedSemicolon;

        switch (self.currentToken().type) {
            .Semicolon => {
                endSpan = self.currentToken().span;
                self.advance(); // Consume the semicolon
            },
            .Eof => {},
            else => {
                // The expression was parsed, but it's followed by an unexpected token instead of a semicolon or EOF.
                std.debug.print("Error: Unexpected token at `{s}` at {any}\n", .{ self.currentToken().type, self.currentToken().span });
                return error.ExpectedSemicolonOrEofAfterExpression;
            },
        }

        return try self.makePointer(Expression, .{
            .kind = expr.*.kind,
            .span = Span.join(startSpan, endSpan),
        });
    }

    fn parseVariableDeclaration(self: *Parser) !*Expression {
        const startSpan = self.currentToken().span;
        self.advance(); // consume let

        const name = try self.expectIdent();
        try self.expectToken(.Colon);

        var ty: ?[]const u8 = null;

        if (self.currentToken().type == .Identifier) {
            ty = try self.expectIdent();
        }

        try self.expectToken(.Equal);
        const val = try self.parseExpression(.Lowest);

        const endSpan = val.span;

        return self.makePointer(Expression, .{
            .kind = .{ .VariableDeclaration = .{
                .name = name,
                .value = val,
                .type = ty,
            } },
            .span = Span.join(startSpan, endSpan),
        });
    }

    fn parseVariableIdentifier(self: *Parser) !*Expression {
        const start_span = self.currentToken().span;
        const ident = try self.expectIdent();
        return self.makePointer(Expression, .{
            .kind = .{ .Identifier = ident },
            .span = Span.join(start_span, start_span),
        });
    }

    fn parseFunctionParameter(self: *Parser) !*const FunctionParameter {
        const name = try self.expectIdent();
        try self.expectToken(.Colon);
        const ty = try self.expectIdent();

        return self.makePointer(FunctionParameter, .{
            .name = name,
            .type = ty,
        });
    }

    fn parseFunctionDeclaration(self: *Parser) !*Expression {
        const startSpan = self.currentToken().span;
        self.advance(); // consume fn
        try self.expectToken(.LParen);

        var params = std.ArrayList(*const FunctionParameter).init(self.alloc);
        while (self.peek().type != .RParen) {
            try params.append(try self.parseFunctionParameter());
            if (self.currentToken().type == .Comma) try self.expectToken(.Comma) else break;
        }

        try self.expectToken(.RParen);

        var returnType: ?*const Expression = null;
        if (self.currentToken().type == .Colon) {
            try self.expectToken(.Colon);
            const returnTypeSpan = self.currentToken().span;
            const returnTypeStr = try self.expectIdent();
            returnType = try self.makePointer(Expression, .{
                .kind = .{ .Identifier = returnTypeStr },
                .span = returnTypeSpan,
            });
        }

        try self.expectToken(.RightArrow);

        if (self.currentToken().type != .LBrace) {
            // NOTE: dont know about this one
            const bodyExpr = try self.parseExpression(.Lowest);
            const endSpan = bodyExpr.*.span;

            var b = std.ArrayList(*Expression).init(self.alloc);
            try b.append(try self.makePointer(Expression, .{
                .kind = bodyExpr.*.kind,
                .span = bodyExpr.*.span,
            }));

            return self.makePointer(Expression, .{
                .kind = .{ .FunctionDeclaration = .{
                    .parameters = params,
                    .returnType = returnType,
                    .body = b,
                } },
                .span = Span.join(startSpan, endSpan),
            });
        }

        const block = try self.parseBlockExpression();
        const endSpan = block.*.span;

        return self.makePointer(Expression, .{
            .kind = .{ .FunctionDeclaration = .{
                .parameters = params,
                .returnType = returnType,
                .body = block.*.kind.Block.body,
            } },
            .span = Span.join(startSpan, endSpan),
        });
    }

    fn parseBlockExpression(self: *Parser) !*Expression {
        const startSpan = self.currentToken().span;
        try self.expectToken(.LBrace); // consume '{'

        var expressions = std.ArrayList(*Expression).init(self.alloc);
        while (self.currentToken().type != .RBrace) {
            const expr = try self.parseTopLevelExpression();
            try expressions.append(expr);
        }

        const endSpan = self.currentToken().span;

        try self.expectToken(.RBrace); // consume '}'

        return self.makePointer(Expression, .{
            .kind = .{ .Block = .{ .body = expressions } },
            .span = Span.join(startSpan, endSpan),
        });
    }

    fn parseExpression(self: *Parser, prec: Precedence) anyerror!*Expression {
        var expr = switch (self.currentToken().type) {
            .IntLiteral => try self.parseIntLiteral(),
            .LParen => try self.parseGroupExpression(),
            .True, .False => try self.parseBoolLiteral(),
            .Plus, .Minus, .Bang => try self.parseUnaryExpression(),
            .Identifier => try self.parseVariableIdentifier(),
            .KeywordFn => try self.parseFunctionDeclaration(),
            .KeywordLet => try self.parseVariableDeclaration(),
            // NOTE: Not sure if this is the right place for this
            .LBrace => try self.parseBlockExpression(),
            else => {
                std.debug.print("Error: No prefix parse function for token type `{s}` at {any}\n", .{
                    self.currentToken().type, self.currentToken().span,
                });
                return error.NoParseFunctionForTokenType;
            },
        };

        while (self.currentToken().type != .Semicolon and self.currentToken().type != .Eof and @intFromEnum(prec) < self.currentPrec()) {
            const operatorType = self.currentToken().type;
            const semanticOp: ?BinaryOperator = getBinaryOperator(operatorType);

            if (semanticOp == null) {
                return expr;
            }

            expr = try self.parseBinaryExpression(expr, semanticOp.?, self.getTokenPrec(operatorType));
        }

        return expr;
    }

    fn getBinaryOperator(tokenType: TokenType) ?BinaryOperator {
        return switch (tokenType) {
            .Plus => .Plus,
            .Minus => .Minus,
            .Star => .Multiply,
            .Slash => .Divide,
            .DoubleEqual => .Equal,
            .NotEqual => .NotEqual,
            .LessThan => .LessThan,
            .GreaterThan => .GreaterThan,
            .LessThanOrEqual => .LessThanOrEqual,
            .GreaterThanOrEqual => .GreaterThanOrEqual,
            .DoubleAmpersand => .LogicalAnd,
            .DoublePipe => .LogicalOr,
            .Caret => .Exponent,
            else => null,
        };
    }

    fn getUnaryOperator(tokenType: TokenType) ?UnaryOperator {
        return switch (tokenType) {
            .Plus => .Plus,
            .Minus => .Minus,
            .Bang => .Not,
            else => null,
        };
    }

    fn parseUnaryExpression(self: *Parser) !*Expression {
        const opToken = self.currentToken();
        const op = getUnaryOperator(opToken.type) orelse return {
            std.debug.print("Error: Invalid token for unary operator {any}\n", .{opToken});
            return error.InvalidUnaryOperator;
        };

        self.advance();

        const rhs = try self.parseExpression(.Prefix);

        return self.makePointer(Expression, .{
            .kind = .{ .Unary = .{ .operator = op, .right = rhs } },
            .span = Span.join(opToken.span, rhs.span),
        });
    }

    fn parseGroupExpression(self: *Parser) !*Expression {
        self.advance(); // consume '('
        const expr = try self.parseExpression(.Lowest);
        if (self.currentToken().type != .RParen) {
            return error.ExpectedRParen;
        }
        self.advance(); // consume ')'
        return expr;
    }

    fn isOperandStart(t: TokenType) bool {
        return switch (t) {
            .IntLiteral, .Identifier, .True, .False, .LParen => true,
            else => false,
        };
    }

    fn parseBinaryExpression(self: *Parser, lhs: *Expression, op: BinaryOperator, prec: Precedence) !*Expression {
        self.advance();

        // TODO: this is a hack, we should change this function's implementation. Maybe add a `allowPrefix` parameter?

        // if (self.currentToken().type == .Plus or self.currentToken().type == .Minus or self.currentToken().type == .Bang) {
        //     return error.UnexpectedUnaryOperator;
        // }
        // if (!isOperandStart(self.currentToken().type)) {
        //     std.debug.print("Error: Expected operand after binary operator at {any}\n", .{self.currentToken().span});
        //     return error.UnexpectedUnaryAfterBinary;
        // }

        // TODO: THIS IS A MAJOR HACK. We should check if `op` is right associative
        const rightPrecAdjust = if (op == .Exponent) @intFromEnum(prec) - 1 else @intFromEnum(prec);
        const rhs = try self.parseExpression(@as(Precedence, @enumFromInt(rightPrecAdjust)));

        const exprSpan = Span.join(lhs.span, rhs.span);
        return self.makePointer(Expression, .{
            .kind = .{ .Binary = .{
                .left = lhs,
                .operator = op,
                .right = rhs,
            } },
            .span = exprSpan,
        });
    }

    fn expectToken(self: *Parser, tokenType: TokenType) !void {
        if (std.meta.activeTag(self.currentToken().type) != tokenType) {
            std.debug.print(
                "Error: Expected token `{s}` but got `{s}` at {any}\n",
                .{ tokenType, self.currentToken().type, self.currentToken().span },
            );
            return error.UnexpectedTokenType;
        }
        self.advance();
    }

    fn expectIdent(self: *Parser) ![]const u8 {
        switch (self.currentToken().type) {
            .Identifier => |ident| {
                self.advance();
                return ident;
            },
            else => return error.ExpectedIdentifier,
        }
    }

    fn parseBoolLiteral(self: *Parser) !*Expression {
        const boolToken = self.currentToken();
        const value = switch (boolToken.type) {
            .True => true,
            .False => false,
            else => unreachable,
        };

        self.advance();

        return self.makePointer(Expression, .{
            .kind = .{ .BoolLiteral = value },
            .span = boolToken.span,
        });
    }

    fn parseIntLiteral(self: *Parser) !*Expression {
        const intToken = self.currentToken();

        const value = switch (intToken.type) {
            .IntLiteral => |int| int,
            else => return error.ExpectedInt,
        };

        self.advance();

        return try self.makePointer(Expression, .{
            .kind = .{ .IntLiteral = value },
            .span = intToken.span,
        });
    }

    fn advance(self: *Parser) void {
        if (self.current < self.tokens.len - 1) {
            self.current += 1;
        }
    }

    fn currentToken(self: *Parser) Token {
        return self.tokens[self.current];
    }

    fn peek(self: *const Parser) Token {
        if (self.current + 1 >= self.tokens.len) {
            return self.tokens[self.tokens.len - 1];
        }

        return self.tokens[self.current + 1];
    }

    fn getTokenPrec(_: *Parser, tokenType: TokenType) Precedence {
        return switch (tokenType) {
            .DoubleAmpersand => .Logical,
            .DoublePipe => .Logical,

            .DoubleEqual => .Equality,
            .NotEqual => .Equality,

            .LessThan => .Comparison,
            .GreaterThan => .Comparison,
            .LessThanOrEqual => .Comparison,
            .GreaterThanOrEqual => .Comparison,

            .Plus => .Sum,
            .Minus => .Sum,

            .Star => .Product,
            .Slash => .Product,

            .Caret => .Exponent,

            .LParen => .Group,

            else => .Lowest,
        };
    }

    fn currentPrec(self: *Parser) u8 {
        return @intFromEnum(self.getTokenPrec(self.currentToken().type));
    }
};
