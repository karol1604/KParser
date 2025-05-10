const std = @import("std");
const token = @import("tokens.zig");
const ast = @import("ast.zig");
const utils = @import("utils.zig");
const span = @import("span.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const Span = span.Span;
const Location = span.Location;

const Precedence = ast.Precedence;
const Expression = ast.Expression;
const BinaryOperator = ast.BinaryOperator;
const UnaryOperator = ast.UnaryOperator;
const Statement = ast.Statement;

pub const Parser = struct {
    tokens: []const Token,
    alloc: std.mem.Allocator,
    current: usize = 0,
    line: usize = 1,

    pub fn init(tokens: []const Token, alloc: std.mem.Allocator) Parser {
        return Parser{ .tokens = tokens, .alloc = alloc };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    fn make_expression_pointer(self: *const Parser, expr: Expression) !*Expression {
        const ptr = try self.alloc.create(Expression);
        ptr.* = expr;
        return ptr;
    }

    fn make_statement_pointer(self: *const Parser, stmt: Statement) !*Statement {
        const ptr = try self.alloc.create(Statement);
        ptr.* = stmt;
        return ptr;
    }

    pub fn parse(self: *Parser) !std.ArrayList(*Statement) {
        var statements = std.ArrayList(*Statement).init(self.alloc);
        errdefer statements.deinit();

        while (self.current_token().type != .Eof) {
            const stmt = try self.parse_statement();
            try statements.append(stmt);
        }

        return statements;
    }

    fn parse_statement(self: *Parser) !*Statement {
        return switch (self.current_token().type) {
            .Let => self.parse_let_statement(),
            else => self.parse_expression_statement(),
        };
    }

    fn parse_let_statement(self: *Parser) !*Statement {
        const start_span = self.current_token().span;
        self.advance(); // consume let

        const name = try self.expect_ident();
        try self.expect_token(.Equal);
        const val = try self.parse_expression(.Lowest);

        var end_span = val.span;

        switch (self.current_token().type) {
            .Semicolon => {
                end_span = self.current_token().span;
                self.advance(); // Consume the semicolon
            },
            .Eof => {},
            else => {
                std.debug.print(
                    "Error: Expected semicolon or EOF after let statement value at {any}\n",
                    .{self.current_token().span},
                );
                return error.ExpectedSemicolonOrEofAfterExpression;
            },
        }
        return self.make_statement_pointer(Statement{
            .type = .{ .LetStatement = .{
                .name = name,
                .value = val,
            } },
            .span = Span.sum(start_span, end_span),
        });
    }

    fn parse_expression_statement(self: *Parser) !*Statement {
        const expr = try self.parse_expression(.Lowest);
        const start_span = expr.span;
        var end_span = start_span;
        // Not sure about the first if part
        // if (self.peek().type == .Eof or self.current_token().type == .Semicolon) {
        //     self.advance();
        // } else return error.ExpectedSemicolon;

        switch (self.current_token().type) {
            .Semicolon => {
                end_span = self.current_token().span;
                self.advance(); // Consume the semicolon
            },
            .Eof => {},
            else => {
                // The expression was parsed, but it's followed by an unexpected token instead of a semicolon or EOF.
                std.debug.print("Error: Unexpected token at {any}, line {any}\n", .{ self.current_token().type, self.current_token().span });
                return error.ExpectedSemicolonOrEofAfterExpression;
            },
        }

        const stmt = Statement{
            .type = .{ .ExpressionStatement = expr },
            .span = Span.sum(start_span, end_span),
        };
        return try self.make_statement_pointer(stmt);
    }

    fn parse_expression(self: *Parser, prec: Precedence) anyerror!*Expression {
        var expr = switch (self.current_token().type) {
            .IntLiteral => try self.parse_int_literal(),
            .LParen => try self.parse_group_expression(),
            .True, .False => try self.parse_bool_literal(),
            .Plus, .Minus, .Bang => try self.parse_unary_expression(),
            else => {
                std.debug.print("Error: No prefix parse function for token type {any} at {any}\n", .{
                    self.current_token().type, self.current_token().span,
                });
                return error.NoParseFunctionForTokenType;
            },
        };

        // while (self.current_prec() > @intFromEnum(prec)) {
        //     // we probably can abstrct this away into a single function call
        //     switch (self.current_token().type) {
        //         .IntLiteral => return error.ConsecutiveInts, // TODO: this condition is actually never reached, fix this bug! (potentially replace > with >= but idk)
        //         .Plus => expr = try self.parse_binary_expression(expr, .Plus, .Sum),
        //         .Minus => expr = try self.parse_binary_expression(expr, .Minus, .Sum),
        //
        //         .Star => expr = try self.parse_binary_expression(expr, .Multiply, .Product),
        //         .Slash => expr = try self.parse_binary_expression(expr, .Divide, .Product),
        //
        //         .DoubleEqual => expr = try self.parse_binary_expression(expr, .Equal, .Equality),
        //         .NotEqual => expr = try self.parse_binary_expression(expr, .NotEqual, .Equality),
        //
        //         .LessThan => expr = try self.parse_binary_expression(expr, .LessThan, .Comparison),
        //         .GreaterThan => expr = try self.parse_binary_expression(expr, .GreaterThan, .Comparison),
        //         .LessThanOrEqual => expr = try self.parse_binary_expression(expr, .LessThanOrEqual, .Comparison),
        //         .GreaterThanOrEqual => expr = try self.parse_binary_expression(expr, .GreaterThanOrEqual, .Comparison),
        //
        //         .DoubleAmpersand => expr = try self.parse_binary_expression(expr, .LogicalAnd, .Logical),
        //         .DoublePipe => expr = try self.parse_binary_expression(expr, .LogicalOr, .Logical),
        //
        //         .Caret => expr = try self.parse_binary_expression(expr, .Exponent, .Exponent),
        //         .Eof => return expr,
        //         else => return error.InvalidOperator,
        //     }
        // }
        while (self.current_token().type != .Semicolon and self.current_token().type != .Eof and @intFromEnum(prec) < self.current_prec()) {
            const operator_type = self.current_token().type;
            const semantic_op: ?BinaryOperator = get_binary_operator(operator_type);

            if (semantic_op == null) {
                return expr;
            }
            // Check for the consecutive integers bug more directly
            // This check should ideally be before trying to parse a binary operator
            // if (operator_type == .IntLiteral) { // This was the original TODO
            //     std.debug.print("Error: Consecutive integer literals without operator at {any}\n", .{self.current_token().span});
            //     return error.ConsecutiveInts;
            // }

            expr = try self.parse_binary_expression(expr, semantic_op.?, self.get_token_prec(operator_type));
        }

        return expr;
    }

    fn get_binary_operator(token_type: TokenType) ?BinaryOperator {
        return switch (token_type) {
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

    fn get_unary_operator(token_type: TokenType) ?UnaryOperator {
        return switch (token_type) {
            .Plus => .Plus,
            .Minus => .Minus,
            .Bang => .Not,
            else => null,
        };
    }

    fn parse_unary_expression(self: *Parser) !*Expression {
        const op_token = self.current_token();
        const op = get_unary_operator(op_token.type) orelse return {
            std.debug.print("Error: Invalid token for unary operator {any}\n", .{op_token});
            return error.InvalidUnaryOperator;
        };

        self.advance();

        const rhs = try self.parse_expression(.Prefix);

        return self.make_expression_pointer(.{
            .type = .{ .Unary = .{ .operator = op, .right = rhs } },
            .span = Span.sum(op_token.span, rhs.span),
        });
    }

    fn parse_group_expression(self: *Parser) !*Expression {
        self.advance(); // consume '('
        const expr = try self.parse_expression(.Lowest);
        if (self.current_token().type != .RParen) {
            return error.ExpectedRParen;
        }
        self.advance(); // consume ')'
        return expr;
    }

    fn is_operand_start(t: TokenType) bool {
        return switch (t) {
            .IntLiteral, .Identifier, .True, .False, .LParen => true,
            else => false,
        };
    }

    fn parse_binary_expression(self: *Parser, lhs: *Expression, op: BinaryOperator, prec: Precedence) !*Expression {
        self.advance();

        // TODO: this is a hack, we should change this function's implementation. Maybe add a `allow_prefix` parameter?
        // if (self.current_token().type == .Plus or self.current_token().type == .Minus or self.current_token().type == .Bang) {
        //     return error.UnexpectedUnaryOperator;
        // }
        if (!is_operand_start(self.current_token().type)) {
            std.debug.print("Error: Expected operand after binary operator at {any}\n", .{self.current_token().span});
            return error.UnexpectedUnaryAfterBinary;
        }

        // TODO: THIS IS A MAJOR HACK. We should check if `op` is right associative
        const right_prec_adjust = if (op == .Exponent) @intFromEnum(prec) - 1 else @intFromEnum(prec);
        const rhs = try self.parse_expression(@as(Precedence, @enumFromInt(right_prec_adjust)));

        const expr_span = Span.sum(lhs.span, rhs.span);
        return self.make_expression_pointer(.{
            .type = .{ .Binary = .{
                .left = lhs,
                .operator = op,
                .right = rhs,
            } },
            .span = expr_span,
        });
    }

    fn expect_token(self: *Parser, token_type: TokenType) !void {
        if (std.meta.activeTag(self.current_token().type) != token_type) {
            return error.UnexpectedTokenType;
        }
        self.advance();
    }

    fn expect_ident(self: *Parser) ![]const u8 {
        switch (self.current_token().type) {
            .Identifier => |ident| {
                self.advance();
                return ident;
            },
            else => return error.ExpectedIdentifier,
        }
    }

    // TODO: REMOVE THIS FUNCTION
    fn expect_int(self: *Parser) !i64 {
        const current = self.current_token();
        switch (self.current_token().type) {
            .IntLiteral => |int| {
                self.advance();
                return int;
            },
            else => {
                std.debug.print("Error: Expected int literal but got {any} at {any}\n", .{
                    current.type, current.span,
                });
                return error.ExpectedInt;
            },
        }
    }

    fn parse_bool_literal(self: *Parser) !*Expression {
        const bool_token = self.current_token();
        const value = switch (bool_token.type) {
            .True => true,
            .False => false,
            else => unreachable,
        };

        self.advance();

        return self.make_expression_pointer(.{
            .type = .{ .BoolLiteral = value },
            .span = bool_token.span,
        });
    }

    fn parse_int_literal(self: *Parser) !*Expression {
        const int_token = self.current_token();

        const value = switch (int_token.type) {
            .IntLiteral => |int| int,
            else => return error.ExpectedInt,
        };

        self.advance();
        return try self.make_expression_pointer(.{
            .type = .{ .IntLiteral = value },
            .span = int_token.span,
        });
    }

    fn advance(self: *Parser) void {
        if (self.current < self.tokens.len - 1) {
            self.current += 1;
        }
    }

    fn current_token(self: *Parser) Token {
        // if (self.current >= self.tokens.len) {
        //     const tok_span = Span{
        //         .start = Location{ .line = self.line, .column = 0, .offset = 0 },
        //         .end = Location{ .line = self.line, .column = 0, .offset = 0 },
        //     };
        //     return Token{ .type = .Eof, .span = tok_span };
        // }
        return self.tokens[self.current];
    }

    fn peek(self: *const Parser) Token {
        if (self.current + 1 >= self.tokens.len) {
            return self.tokens[self.tokens.len - 1];
        }

        return self.tokens[self.current + 1];
    }

    fn get_token_prec(_: *Parser, token_type: TokenType) Precedence {
        return switch (token_type) {
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

            else => Precedence.Lowest,
        };
    }

    fn current_prec(self: *Parser) u8 {
        return @intFromEnum(self.get_token_prec(self.current_token().type));
    }
};
