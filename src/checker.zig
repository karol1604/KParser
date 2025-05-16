const std = @import("std");
const ast = @import("ast.zig");
const utils = @import("utils.zig");
const span_ = @import("span.zig");

const Span = span_.Span;

const TypeId = usize;

const EMPTY_TYPE_ID: TypeId = 0;
const INT_TYPE_ID: TypeId = 1;
const BOOL_TYPE_ID: TypeId = 2;

const CheckedStatement = struct {
    expr: *const CheckedExpression,
};

pub const CheckedExpression = struct {
    typeId: TypeId,
    data: CheckedExpressionData,
};

const CheckedFunctionParameter = struct {
    name: []const u8,
    typeId: TypeId,
};

const CheckedExpressionData = union(enum) {
    IntLiteral: i64,
    BoolLiteral: bool,
    Identifier: []const u8,

    Unary: struct {
        operator: ast.UnaryOperator,
        right: *const CheckedExpression,
    },

    Binary: struct {
        left: *const CheckedExpression,
        operator: ast.BinaryOperator,
        right: *const CheckedExpression,
    },

    VariableDeclaration: struct {
        name: []const u8,
        value: *const CheckedExpression,
    },

    FunctionDeclaration: struct {
        parameters: std.ArrayList(*CheckedFunctionParameter),
        returnType: TypeId,
        body: std.ArrayList(*CheckedStatement),
    },
};

const Scope = struct {
    variables: std.StringHashMap(TypeId),
    types: std.StringHashMap(TypeId),

    pub fn init(alloc: std.mem.Allocator) !Scope {
        return Scope{
            .variables = std.StringHashMap(TypeId).init(alloc),
            .types = std.StringHashMap(TypeId).init(alloc),
        };
    }

    pub fn deinit(self: *Scope) void {
        self.variables.deinit();
        self.types.deinit();
    }
};

pub const Checker = struct {
    alloc: std.mem.Allocator,
    statements: []*ast.Statement,
    types: std.ArrayList([]const u8),
    scopes: std.ArrayList(Scope),

    pub fn init(alloc: std.mem.Allocator, stmts: []*ast.Statement) !Checker {
        var scopes = std.ArrayList(Scope).init(alloc);
        errdefer {
            for (scopes.items) |*scope| scope.deinit();
            scopes.deinit();
        }

        try scopes.append(try Scope.init(alloc));

        var types = std.ArrayList([]const u8).init(alloc);
        errdefer types.deinit();

        try types.append("Empty");
        try types.append("Int");
        try types.append("Bool");

        var c = Checker{
            .alloc = alloc,
            .statements = stmts,
            .types = types,
            .scopes = scopes,
        };

        try c.declareType("Empty", EMPTY_TYPE_ID);
        try c.declareType("Int", INT_TYPE_ID);
        try c.declareType("Bool", BOOL_TYPE_ID);

        return c;
    }

    fn makePointer(self: *const Checker, comptime T: type, val: T) !*T {
        const ptr = try self.alloc.create(T);
        ptr.* = val;
        return ptr;
    }

    fn typeNameFromId(self: *Checker, id: TypeId) ?[]const u8 {
        for (self.scopes.items) |*scope| {
            var it = scope.types.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == id) {
                    return entry.key_ptr.*;
                }
            }
        }

        return null;
    }

    fn currentScope(self: *Checker) *Scope {
        return &self.scopes.items[self.scopes.items.len - 1];
    }

    fn pushScope(self: *Checker) !void {
        const newScope = try Scope.init(self.alloc);
        try self.scopes.append(newScope);
    }

    fn popScope(self: *Checker) void {
        const last = self.scopes.items.len - 1;
        self.scopes.items[last].deinit();
        _ = self.scopes.pop();
    }

    fn declareType(self: *Checker, name: []const u8, id: TypeId) !void {
        const scope = self.currentScope();
        if (scope.types.get(name) != null) {
            std.debug.print("Type `{s}` already declared\n", .{name});
            return error.TypeAlreadyDeclared;
        }
        try scope.types.put(name, id);
    }

    fn lookupType(self: *Checker, name_: ?[]const u8) ?TypeId {
        if (name_) |name| {
            for (self.scopes.items) |*scope| {
                if (scope.types.get(name) != null) {
                    return scope.types.get(name);
                }
            }
        }
        return null;
    }

    fn declareVar(self: *Checker, name: []const u8, type_id: TypeId) !void {
        const scope = self.currentScope();
        if (scope.variables.get(name) != null) {
            std.debug.print("Variable `{s}` already declared\n", .{name});
            return error.VariableAlreadyDeclared;
        }
        try scope.variables.put(name, type_id);
    }

    fn lookupVar(self: *Checker, name: []const u8) ?TypeId {
        for (self.scopes.items) |*scope| {
            if (scope.variables.get(name) != null) {
                return scope.variables.get(name);
            }
        }
        return null;
    }

    pub fn check(self: *Checker) !std.ArrayList(*CheckedStatement) {
        var checkedStatements = std.ArrayList(*CheckedStatement).init(self.alloc);
        errdefer checkedStatements.deinit();

        for (self.statements) |stmt| {
            const checkedStmt = try self.checkStatement(stmt);
            try checkedStatements.append(checkedStmt);
            // Do something with checkedStmt
        }

        return checkedStatements;
    }

    fn checkStatement(self: *Checker, stmt: *const ast.Statement) !*CheckedStatement {
        var expr: *const CheckedExpression = undefined;
        switch (stmt.*.kind) {
            ast.StatementKind.ExpressionStatement => |exprStmt| {
                expr = try self.checkExpression(exprStmt, null);
            },
            ast.StatementKind.VariableDeclaration => |varDecl| {
                const expectedType = self.lookupType(varDecl.type);

                // really?
                if (expectedType == null) {
                    if (varDecl.type) |typeName| {
                        std.debug.print("Unknown type `{s}` at {any}\n", .{ typeName, stmt.*.span });
                        return error.UnknownType;
                    }
                }

                const value = try self.checkExpression(varDecl.value, expectedType);
                try self.declareVar(varDecl.name, value.typeId);
                expr = try self.typedExpression(.{
                    .VariableDeclaration = .{
                        .name = varDecl.name,
                        .value = value,
                    },
                }, stmt.*.span, EMPTY_TYPE_ID, null);
            },
            else => return error.NotYetImplemented,
        }

        return try self.makePointer(CheckedStatement, CheckedStatement{
            .expr = expr,
        });
    }

    fn checkExpression(self: *Checker, expr: *const ast.Expression, typeHint: ?TypeId) anyerror!*CheckedExpression {
        switch (expr.*.kind) {
            .IntLiteral => |int| {
                return try self.typedExpression(.{ .IntLiteral = int }, expr.*.span, INT_TYPE_ID, typeHint);
            },
            .BoolLiteral => |b| {
                return try self.typedExpression(.{ .BoolLiteral = b }, expr.*.span, BOOL_TYPE_ID, typeHint);
            },
            .Identifier => |ident| {
                // const scope = self.currentScope();
                // const typeId = scope.variables.get(ident);
                const typeId = self.lookupVar(ident);
                if (typeId) |ty| {
                    return try self.typedExpression(.{ .Identifier = ident }, expr.*.span, ty, typeHint);
                } else {
                    std.debug.print("Unknown variable `{s}` at {any}\n", .{ ident, expr.*.span });
                    return error.UnknownVariable;
                }
            },

            .FunctionDeclaration => |decl| {
                const returnType = self.lookupType(decl.returnType).?;
                var params = std.ArrayList(*CheckedFunctionParameter).init(self.alloc);
                var body = std.ArrayList(*CheckedStatement).init(self.alloc);

                try self.pushScope();

                for (decl.parameters.items) |param| {
                    const paramType = self.lookupType(param.type);
                    if (paramType == null) {
                        std.debug.print("Unknown type `{s}` at {any}\n", .{ param.type, expr.*.span });
                        return error.UnknownType;
                    }
                    try params.append(try self.makePointer(CheckedFunctionParameter, .{
                        .name = param.name,
                        .typeId = paramType.?,
                    }));
                    try self.declareVar(param.name, paramType.?);
                }

                for (decl.body.items) |stmt| {
                    const checkedStmt = try self.checkStatement(stmt);
                    try body.append(checkedStmt);
                }

                const lastStmtTypeId = body.items[body.items.len - 1].*.expr.*.typeId;
                if (returnType != lastStmtTypeId) {
                    std.debug.print("Type mismatch: Function return type marked as `{s}` but returns `{s}` at {any}\n", .{ self.typeNameFromId(returnType).?, self.typeNameFromId(lastStmtTypeId).?, expr.*.span });
                    return error.FunctionReturnTypeMismatch;
                }

                self.popScope();

                return self.typedExpression(
                    .{ .FunctionDeclaration = .{
                        .parameters = params,
                        .returnType = returnType,
                        .body = body,
                    } },
                    expr.*.span,
                    EMPTY_TYPE_ID,
                    typeHint,
                );
            },
            .Unary => |unary| {
                switch (unary.operator) {
                    .Not => {
                        const right = try self.checkExpression(unary.right, BOOL_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Unary = .{
                                .operator = unary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
                        );
                    },
                    .Plus, .Minus => {
                        const right = try self.checkExpression(unary.right, INT_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Unary = .{
                                .operator = unary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            INT_TYPE_ID,
                            typeHint,
                        );
                    },
                }
            },

            .Binary => |binary| {
                switch (binary.operator) {
                    .Plus, .Minus, .Multiply, .Divide, .Exponent => {
                        const left = try self.checkExpression(binary.left, INT_TYPE_ID);
                        const right = try self.checkExpression(binary.right, INT_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            INT_TYPE_ID,
                            typeHint,
                        );
                    },
                    .LessThan, .GreaterThan, .LessThanOrEqual, .GreaterThanOrEqual => {
                        const left = try self.checkExpression(binary.left, INT_TYPE_ID);
                        const right = try self.checkExpression(binary.right, INT_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
                        );
                    },
                    .Equal, .NotEqual => {
                        const left = try self.checkExpression(binary.left, null);
                        const right = try self.checkExpression(binary.right, left.typeId);

                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
                        );
                    },
                    .LogicalAnd, .LogicalOr => {
                        const left = try self.checkExpression(binary.left, BOOL_TYPE_ID);
                        const right = try self.checkExpression(binary.right, BOOL_TYPE_ID);

                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
                        );
                    },
                    // else => {
                    //     return error.UnknownBinaryOperator;
                    // },
                }
            },
            // else => {
            //     std.debug.print("Unknown expression type \n", .{});
            //     return error.UnknownExpressionType;
            // },
        }
    }

    fn typedExpression(self: *Checker, res: CheckedExpressionData, span: Span, resType: TypeId, typeHint: ?TypeId) !*CheckedExpression {
        if (typeHint) |hint| {
            if (resType != hint) {
                std.debug.print("Type mismatch: expected type {s}, got {s} at {s}\n", .{ self.typeNameFromId(hint).?, self.typeNameFromId(resType).?, span });
                return error.TypeMismatch;
            } else {
                return self.makePointer(CheckedExpression, CheckedExpression{
                    .typeId = resType,
                    .data = res,
                });
            }
        } else {
            return self.makePointer(CheckedExpression, CheckedExpression{
                .typeId = resType,
                .data = res,
            });
        }
    }
};
